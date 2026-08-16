//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** Implementation of LibFiles
**
@Js
const class MLibFiles : LibFiles
{
  static const MLibFiles empty := make(Uri:LibFile[:])

  internal new make(Uri:LibFile map)
  {
    this.map         = map
    this.list        = map.vals.sort
    this.published   = list.findAll { it.isPublished }
    this.hasChapters = published.any { XetoUtil.isChapter(it.uri) }
  }

  override Bool isSupported() { true }

  override const LibFile[] list

  override const LibFile[] published

  private const Uri:LibFile map

  const Bool hasChapters

  override LibFile? get(Uri uri, Bool checked := true)
  {
    f := map.get(uri)
    if (f != null) return f
    if (checked) throw UnresolvedErr(uri.toStr)
    return null
  }

  Void dump(Console con := Console.cur)
  {
    list.each |f|
    {
      suffix := f.isPublished ? "(pub)" : ""
      con.info("$f.uri $suffix")
    }
  }

  override Void close() {}
}

**************************************************************************
** MLibFile
**************************************************************************

@Js
const class MLibFile : LibFile
{
  new make(Uri uri, File file, Bool isPublished)
  {
    this.uri         = uri
    this.file        = file
    this.isPublished = isPublished
  }

  const override Uri uri
  const File file
  const override Bool isPublished
  override Obj? read(|InStream->Obj?| f) { file.withIn(f) }
  override Str readAllStr() { file.readAllStr }
  override Int? size() { file.size }
  override DateTime? modified() { file.modified }
  override FileLoc loc() { FileLoc(file) }
}

**************************************************************************
** UnsupportedLibFiles
**************************************************************************

@Js
const class UnsupportedLibFiles : LibFiles
{
  static const UnsupportedLibFiles val := make
  private new make() {}

  override Bool isSupported() { false }
  override LibFile[] list() { throw UnsupportedErr() }
  override LibFile[] published() { throw UnsupportedErr() }
  override LibFile? get(Uri uri, Bool checked := true) { throw UnsupportedErr()  }
  override Void close() {}
}

**************************************************************************
** ZipLibFilesScanner
**************************************************************************

** Scan the files in a xetolib.  Use xeto-meta.props to determine published.
*** NOTE: this leaves the zip file open!
class ZipLibFilesScanner
{
  new make(File zipFile) { this.zipFile = zipFile }

  const File zipFile

  MLibFiles scan()
  {
    zip := Zip.open(zipFile)
    acc := Uri:LibFile[:]
    try
    {
      meta := zip.contents[`/xeto-meta.props`]?.readProps ?: throw Err("Missing xeto-meta.props")
      publish := LibFilePattern.parseFromStrList(meta["publish"])
      zip.contents.each |entry|
      {
        uri := entry.uri

        // skip system files
        if (XetoUtil.isXetoSystemFile(uri.name)) return

        // decide if published (we if not valid name, then silently unpublish)
        isPublished := publish.any { it.matches(uri) } && XetoUtil.isPublishFilePath(uri)

        // accumulate
        acc.add(uri, MLibFile(uri, entry, isPublished))
      }
    }
    catch (Err e)
    {
      zip.close
      throw e
    }
    return ZipLibFiles(zip, acc)
  }
}

internal const class ZipLibFiles : MLibFiles
{
  new make(Zip zip, Uri:LibFile map) : super(map) { this.zipRef = Unsafe(zip) }
  const Unsafe zipRef
  Zip zip() { zipRef.val }
  override Void close() { zip.close }
}

**************************************************************************
** DirLibFilesScanner
**************************************************************************

class DirLibFilesScanner
{
  new make(File root, LibFilePattern[] include, LibFilePattern[] publish)
  {
    this.root   = root
    this.include = include
    this.publish = publish
  }

  MLibFiles scan(|Str msg, File f| onErr)
  {
    this.onErr = onErr
    walk("", root)
    return MLibFiles(acc)
  }

  private Void walk(Str path, File f)
  {
    // recurse a directory
    if (f.isDir)
    {
      f.list.each |sub| { walk(path + "/" + sub.name, sub) }
      return
    }

    // no file can start with "xeto-"
    uri := path.toUri
    if (XetoUtil.isXetoSystemFile(uri.name)) return err("File name cannot use reserved prefix '$XetoUtil.xetoSystemFilePrefix'", f)

    // always accumulate xeto and chapters as published
    if (f.ext == "xeto" || XetoUtil.isChapter(uri)) return add(uri, f, true)

    // skip any other file not published nor included
    isPublished := publish.any { it.matches(uri) }
    isIncluded  := isPublished || include.any { it.matches(uri) }
    if (!isIncluded) return
    add(uri, f, isPublished)
  }

  private Void add(Uri uri, File f, Bool isPublished)
  {
    if (isPublished) checkPublishPath(uri, f)
    acc.add(uri, MLibFile(uri, f, isPublished))
  }

  private Void checkPublishPath(Uri uri, File f)
  {
    uri.path.eachWhile |n|
    {
      e := XetoUtil.publishFileNameErr(n)
      if (e == null) return null
      err(e, f)
      return "break"
    }
  }

  private Void err(Str msg, File f)
  {
    if (onErr == null) return
    onErr(msg, f)
  }

  private const File root
  private const LibFilePattern[] include
  private const LibFilePattern[] publish
  private Uri:LibFile acc := [:]
  private |Str,File|? onErr
}

