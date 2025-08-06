//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jul 2025  Brian Frank  Creation
//

using concurrent

/* TODO
**
** FileBase is a simple map of text files keyed by name stored to disk.
**
abstract const class FileBase
{
  ** List file names
  abstract Str[] list()

  ** Check if file name exists
  abstract Bool exists(Str name)

  ** Read a file by name
  abstract Buf? read(Str name, Bool checked := true)

  ** Write a file by name.  Cannot write empty buf
  abstract Void write(Str name, Buf buf)

  ** Delete a file by name.
  abstract Void delete(Str name)
}

**************************************************************************
** DiskFileBase
**************************************************************************

**
** Simple file system implementation of FileBase
** TODO: add backup support
**
const class DiskFileBase : FileBase
{
  new make(File dir) { this.dir = dir }

  const File dir

  override Str[] list()
  {
    acc := Str:Str[:]
    dir.list.each |f|
    {
      if (f.isDir) return
      name := f.name
      if (f.ext == "backup") name = f.basename
      acc[name] = name
    }
    return acc.keys
  }

  override Bool exists(Str name)
  {
    f := dir + name.toUri
    return f.exists
  }

  override Buf? read(Str name, Bool checked := true)
  {
    f := dir + name.toUri
    if (f.exists)
    {
      Buf buf := f.withIn |in| { in.readAllBuf }
      if (!buf.isEmpty) return buf
    }
    if (checked) throw Err("File not found: $f.osPath")
    return null
  }

  override Void write(Str name, Buf buf)
  {
    f := dir + name.toUri
    buf.seek(0)
    if (buf.isEmpty) throw ArgErr("Cannot write empty file: $name")
    f.withOut |out| { out.writeBuf(buf) }
  }

  override Void delete(Str name)
  {
    f := dir + name.toUri
    f.delete
  }
}
*/

