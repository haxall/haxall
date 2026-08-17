//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Aug 2026  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** LibFileScanner is abstracts scanning LibFiles across xetolib
** zip files, source directories, and single file compiles.
**
@Js
abstract class LibFileScanner
{
  ** Create for the given file
  static LibFileScanner create(File input)
  {
    if (input.ext == "xetolib") return ZipScanner(Zip.open(input))
    if (input.isDir) return DirScanner(input)
    return FileScanner(input)
  }

  ** Is this a xetolib zip file scanner
  virtual Bool isZip() { false }

  ** Read the build vars to be used.  Zip files package
  ** their own vars in "/xeto-build.props".
  virtual BuildVars readBuildVars(BuildVars src) { src }

  ** Get libMeta or return null/non-nonexistent file if missing
  abstract File? libMeta()

  ** Scan prep with filters and error handler
  This scanPrep(LibFilePattern[] include, LibFilePattern[] publish, |Str,FileLoc| onErr)
  {
    this.include = include
    this.publish = publish
    this.onErr   = onErr
    return this
  }

  ** Perform scan - must have called scanPrep
  MLibFiles scan()
  {
    if (onErr == null) throw Err("Must call scanPrep first")
    acc := Uri:LibFile[:]
    doScan |uri, f|
    {
      acc.addNotNull(uri, scanFile(uri, f))
    }
    return MLibFiles(acc)
  }

  private LibFile? scanFile(Uri uri, File f)
  {
    // always skip hidden files
    if (XetoUtil.isHiddenFile(uri.name)) return null

    // no file can start with "xeto-"
    if (XetoUtil.isXetoSystemFile(uri.name))
    {
      // ignore system files in xetolib
      if (isZip) return null

      // report error
      err("Invalid file name '$uri.name': File name cannot use reserved prefix '$XetoUtil.xetoSystemFilePrefix'", FileLoc(f))
      return null
    }

    // sources and chapters are intrinsically published or in 'publish' patterns
    isPublished := XetoUtil.isPublishIntrinsic(uri) || publish.any { it.matches(uri) }

    // includes is anything published or in 'include' patterns
    isIncluded := isPublished || include.any { it.matches(uri) }
    if (!isIncluded) return null

    // if published verify its a valid publish file name
    if (isPublished) checkPublishPath(uri, f)

    // we have a valid publish file
    return MLibFile(uri, f, isPublished)
  }

  ** Report the first invalid section of a published path.  A directory is
  ** walked once per file beneath it, so report each bad name only once.
  private Void checkPublishPath(Uri uri, File f)
  {
    // check file name itself
    e := XetoUtil.publishFileNameErr(uri.name)
    if (e != null) return err("Invalid file name '$uri.name': $e", FileLoc(f))

    // check directory path names (report once)
    uri.path[0..-2].eachWhile |n, i|
    {
      e = XetoUtil.publishFileNameErr(n)
      if (e == null) return null

      badPath := "/" + uri.path[0..i].join("/") + "/"
      if (badPaths[badPath] == null)
      {
        badPaths[badPath] = badPath
        err("Invalid file path name '$n': $e", FileLoc(f))
      }
      return "break"
    }
  }
  ** Scan every file using the normalized lib URI "/foo.ext"
  protected abstract Void doScan(|Uri,File| cb)

  ** Close the scanner if holding resources
  virtual Void close() {}

  ** Invoke the onErr callback
  private Void err(Str msg, FileLoc loc)
  {
    if (onErr == null) return
    onErr(msg, loc)
  }

  private |Str,FileLoc|? onErr
  private LibFilePattern[]? include
  private LibFilePattern[]? publish
  private Str:Str badPaths := [:]
}

**************************************************************************
** ZipScanner
**************************************************************************

@Js
internal class ZipScanner : LibFileScanner
{
  new make(Zip zip) { this.zip = zip }

  override Bool isZip() { true }

  override BuildVars readBuildVars(BuildVars src)
  {
    BuildVars.read(zip.contents[XetoUtil.xetoBuildPropsUri])
  }

  override File? libMeta()
  {
    zip.contents[`/lib.xeto`]
  }

  override Void doScan(|Uri,File| cb)
  {
    zip.contents.each |f,u| { cb(u,f) }
  }

  override Void close()
  {
    try { zip.close } catch {}
  }

  Zip zip
}

**************************************************************************
** DirScanner
**************************************************************************

@Js
internal class DirScanner : LibFileScanner
{
  new make(File root) { this.root = root }

  override File? libMeta() { root.plus(`lib.xeto`) }

  override Void doScan(|Uri,File| cb) { walk("", root, cb) }

  private static Void walk(Str path, File f, |Uri,File| cb)
  {
    if (f.isDir) f.list.each |sub| { walk(path+"/"+sub.name, sub, cb) }
    else cb(path.toUri, f)
  }

  const File root
}

**************************************************************************
** FileScanner
**************************************************************************

@Js
internal class FileScanner : LibFileScanner
{
  new make(File file) { this.file = file }

  override File? libMeta() { file }

  override Void doScan(|Uri,File| cb) {}

  const File file
}

