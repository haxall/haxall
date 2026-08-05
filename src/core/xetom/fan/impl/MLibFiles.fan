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
abstract const class MLibFiles : LibFiles
{
  override Bool isSupported() { true }

  ** Resource files are all the lib files except the ".xeto" sources.
  ** Source dirs exclude hidden files in `LibSrcFiles`, but zips may
  ** contain entries built by other tools so we check here too.
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
  new make(LibSrcFiles src) { this.src = src }

  const LibSrcFiles src

  override Uri[] list() { src.resourceUris }

  override File? get(Uri uri, Bool checked := true)
  {
    f := src.map.get(uri)
    if (f != null && include(f)) return f
    if (checked) throw UnresolvedErr(uri.toStr)
    return null
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
      allow := include(file) || uri.ext == "xeto" // use this to read source too
      if (file != null && allow) return file.readAllBuf.toFile(uri)
      if (checked) throw UnresolvedErr(uri.toStr)
      return null
    }
    finally { zip?.close }
  }

}

