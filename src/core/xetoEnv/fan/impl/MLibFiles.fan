//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using haystack::Marker
using haystack::UnknownSpecErr

**
** Implementation of LibFiles
**
@Js
abstract const class MLibFiles : LibFiles
{
  override Bool isSupported() { true }

  static Bool include(File f)
  {
    if (f.isDir) return false
    if (f.ext == "xeto") return false
    if (f.name.startsWith(".")) return false
    return true
  }
}

**************************************************************************
** UnsupportedLibFiles
**************************************************************************

@Js
const class UnsupportedLibFiles : MLibFiles
{
  static const UnsupportedLibFiles val := make
  private new make() {}

  override Bool isSupported() { false }
  override Uri[] list() { throw UnsupportedErr() }
  override File? get(Uri uri, Bool checked := true) { throw UnsupportedErr()  }
}

**************************************************************************
** EmptyLibFiles
**************************************************************************

@Js
const class EmptyLibFiles : MLibFiles
{
  static const EmptyLibFiles val := make
  private new make() {}
  override Uri[] list() { Uri#.emptyList }
  override File? get(Uri uri, Bool checked := true)
  {
    if (checked) throw UnresolvedErr(uri.toStr)
    return null
  }
}

**************************************************************************
** DirLibFiles
**************************************************************************

@Js
const class DirLibFiles : MLibFiles
{
  new make(File dir) { this.dir = dir }

  const File dir

  override once Uri[] list()
  {
    map.keys.sort.toImmutable
  }

  override File? get(Uri uri, Bool checked := true)
  {
    f := map.get(uri)
    if (f != null) return f
    if (checked) throw UnresolvedErr(uri.toStr)
    return null
  }

  private once Uri:File map()
  {
    acc := Uri:File[:]
    dir.walk |f|
    {
      if (!include(f)) return
      rel := f.uri.toStr[dir.toStr.size-1..-1].toUri
      acc.add(rel, f)
    }
    return acc.toImmutable
  }

}

**************************************************************************
** ZipLibFiles
**************************************************************************

@Js
const class ZipLibFiles : MLibFiles
{
  new make(File zipFile, Uri[] list)
  {
    this.zipFile = zipFile
    this.list = list
  }

  const File zipFile

  override const Uri[] list

  override File? get(Uri uri, Bool checked := true)
  {
    // not ideal reading whole file into memory, but it
    // lets not worry about keeping the zip file open
    Zip? zip
    try
    {
      zip = Zip.open(zipFile)
      file := zip.contents.get(uri)
      if (file != null && include(file)) return file.readAllBuf.toFile(uri)
      if (checked) throw UnresolvedErr(uri.toStr)
      return null
    }
    finally { zip?.close }
  }

}

