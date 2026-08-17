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

  new make(Uri:LibFile map)
  {
    // sort by name but put lib.xeto first
    list := map.vals.sort
    list.moveTo(list.find { it.uri == `/lib.xeto` }, 0)

    this.map       = map
    this.list      = list
    this.published = list.findAll { it.isPublished }
  }

  override Bool isSupported() { true }

  override const LibFile[] list

  override const LibFile[] published

  private const Uri:LibFile map

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

