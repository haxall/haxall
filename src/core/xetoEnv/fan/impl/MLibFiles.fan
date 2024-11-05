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
  override Void read(Uri uri, |Err?,InStream?| f) { throw UnsupportedErr() }
}

**************************************************************************
** EmptyLibFiles
**************************************************************************

@Js
const class EmptyLibFiles : MLibFiles
{
  static const EmptyLibFiles val := make
  private new make() {}

  override Bool isSupported() { true }
  override Uri[] list() { Uri#.emptyList }
  override Void read(Uri uri, |Err?,InStream?| f) { f(UnresolvedErr(uri.toStr), null) }
}

**************************************************************************
** DirLibFiles
**************************************************************************

@Js
const class DirLibFiles : MLibFiles
{
  new make(File dir) { this.dir = dir }

  const File dir

  override Bool isSupported() { true }

  override once Uri[] list()
  {
    acc := Uri[,]
    dir.walk |f|
    {
      if (f.isDir) return
      if (f.ext == "xeto") return
      if (f.name.startsWith(".")) return
      rel := f.uri.toStr[dir.toStr.size-1..-1].toUri
      acc.add(rel)
    }
    acc.sort
    return acc.toImmutable
  }

  override Void read(Uri uri, |Err?,InStream?| f)
  {
    // make sure uri is in our list for security
    if (list.contains(uri))
    {
      // lookup file
      file := dir + uri.relTo(`/`)
      if (file.exists)
      {
        doRead(file, f)
        return
      }
    }

    // callback with unresolved err
    f(UnresolvedErr(uri.toStr), null)
  }

  private Void doRead(File file, |Err?,InStream?| f)
  {
    InStream? in := null
    try
    {
      try
        f(null, in = file.in)
      catch (Err e)
        f(e, null)
    }
    catch (Err e) { }
    finally { in?.close }
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

  override Bool isSupported() { true }

  override const Uri[] list

  override Void read(Uri uri, |Err?,InStream?| f)
  {
    if (list.contains(uri))
      doRead(uri, f)
    else
      f(UnresolvedErr(uri.toStr), null)
  }

  private Void doRead(Uri uri, |Err?,InStream?| f)
  {
    Zip? zip
    try
    {
      InStream? in
      try
      {
        zip = Zip.open(zipFile)
        in = zip.contents.getChecked(uri).in // should exist b/c we already checked
      }
      catch (Err e) { f(e, null); return }
      f(null, in)
    }
    finally { zip?.close }
  }
}

