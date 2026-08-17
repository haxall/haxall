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
** Scanner is abstracts scanning LibFiles across xetolib
** zip files, source directories, and single file compiles.
**
@Js
internal abstract class Scanner
{
  ** Create for the given file
  static Scanner create(ParseStep step)
  {
    input := step.input
    if (input.ext == "xetolib") return ZipScanner(step, input)
    if (input.isDir) return DirScanner(step, input)
    return FileScanner(step, input)
  }

  ** Constructor
  new make(ParseStep step) { this.step = step }

  ** Is this a xetolib zip file scanner
  virtual Bool isZip() { false }

  ** Read the build vars to be used.  Zip files package
  ** their own vars in "/xeto-build.props".
  virtual BuildVars readBuildVars(BuildVars src) { src }

  ** Get libMeta or return null/non-nonexistent file if missing
  abstract File? libMeta()

  ** Scan flag if any chapter resources detected
  Bool hasChapters

  ** Perform scan - must have called scanPrep
  MLibFiles scan(LibFilePattern[] include, LibFilePattern[] publish)
  {
    this.include = include
    this.publish = publish
    acc := Uri:LibFile[:]
    doScan |uri, f| { scanFile(acc, uri, f) }
    return MLibFiles(acc)
  }

  private Void scanFile(Uri:LibFile acc, Uri uri, File f)
  {
    // always skip hidden files
    if (XetoUtil.isHiddenFile(uri.name)) return

    // no file can start with "xeto-"
    if (XetoUtil.isXetoSystemFile(uri.name))
    {
      // ignore system files in xetolib
      if (isZip) return

      // report error
      err("Invalid file name '$uri.name': File name cannot use reserved prefix '$XetoUtil.xetoSystemFilePrefix'", FileLoc(f))
      return
    }

    // sources and chapters are intrinsically published or in 'publish' patterns
    isPublished := XetoUtil.isPublishIntrinsic(uri) || publish.any { it.matches(uri) }

    // includes is anything published or in 'include' patterns
    isIncluded := isPublished || include.any { it.matches(uri) }
    if (!isIncluded) return

    // if published verify its a valid publish file name
    if (isPublished) checkPublishPath(uri, f)

    // we have a valid publish file
    scanAdd(acc, reify(uri, f, isPublished))
  }

  private Void scanAdd(Uri:LibFile acc, LibFile f)
  {
    if (XetoUtil.isChapter(f.uri)) hasChapters = true
    acc.add(f.uri, f)
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

  ** Turn scan uri + file into the proper LibFile instance
  protected abstract LibFile reify(Uri uri, File file, Bool isPublished)

  ** Close the scanner if holding resources
  virtual Void close() {}

  ** Invoke the onErr callback
  private Void err(Str msg, FileLoc loc)
  {
    step.err(msg, loc)
  }

  private ParseStep step
  private LibFilePattern[]? include
  private LibFilePattern[]? publish
  private Str:Str badPaths := [:]
}

**************************************************************************
** ZipScanner
**************************************************************************

@Js
internal class ZipScanner : Scanner
{
  new make(ParseStep step, File zipFile) : super(step)
  {
    this.zipFile = zipFile
    this.zip = Zip.open(zipFile)
  }

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

  override LibFile reify(Uri uri, File file, Bool isPublished)
  {
    ZipLibFile(zipFile, uri, file, isPublished)
  }

  override Void close()
  {
    try { zip.close } catch {}
  }

  private File zipFile
  private Zip zip
}

**************************************************************************
** DirScanner
**************************************************************************

@Js
internal class DirScanner : Scanner
{
  new make(ParseStep step, File root) : super(step) { this.root = root }

  override File? libMeta() { root.plus(`lib.xeto`) }

  override Void doScan(|Uri,File| cb) { walk("", root, cb) }

  private static Void walk(Str path, File f, |Uri,File| cb)
  {
    if (f.isDir) f.list.each |sub| { walk(path+"/"+sub.name, sub, cb) }
    else cb(path.toUri, f)
  }

  override LibFile reify(Uri uri, File file, Bool isPublished)
  {
    LocalLibFile(uri, file, isPublished)
  }

  const File root
}

**************************************************************************
** FileScanner
**************************************************************************

@Js
internal class FileScanner : Scanner
{
  new make(ParseStep step, File file) : super(step)  { this.file = file }

  override File? libMeta() { file }

  override Void doScan(|Uri,File| cb) {}

  override LibFile reify(Uri uri, File file, Bool isPublished)
  {
    LocalLibFile(uri, file, isPublished)
  }

  const File file
}

