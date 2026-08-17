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

