//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jul 2025  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetoc
using hx

**
** ProjSpecs implementation
**
const class MProjSpecs : ProjSpecs
{

  new make(MProjLibs libs)
  {
    this.libs = libs
    this.fb   = libs.fb
  }

  const MProjLibs libs

  const DiskFileBase fb

  override Lib lib()
  {
    libs.ns.lib("proj")
  }

  override Str? libErrMsg()
  {
    err := libs.ns.libErr("proj")
    if (err == null) return null
    if (err is FileLocErr) return ((FileLocErr)err).loc.toFilenameOnly.toStr + ": " + err.msg
    return err.toStr
  }

  override Str[] list()
  {
    fb.list.mapNotNull |n->Str?|
    {
      if (n == "lib.xeto") return null // TODO
      return n.endsWith(".xeto") ? n[0..-6] : null
    }
  }

  override Str? read(Str name, Bool checked := true)
  {
    buf := fb.read("${name}.xeto", false)
    if (buf != null)
    {
      src := buf.readAllStr
      colon := src.index(": ") ?: throw Err("Unexpected src $name.toCode: $src")
      return src[colon+2..-1]
    }
    if (checked) throw UnknownSpecErr("proj::$name")
    return null
  }

  override Spec add(Str name, Str body)
  {
    if (read(name, false) != null) throw DuplicateNameErr("Spec already exists: $name")
    return doUpdate(name, body)
  }

  override Spec update(Str name, Str body)
  {
    read(name)
    return doUpdate(name, body)
  }

  override Spec rename(Str oldName, Str newName)
  {
    body := read(oldName)
    if (read(newName, false) != null) throw DuplicateNameErr("Spec already exists: $newName")
    write(newName, body)
    remove(oldName)
    return lib.spec(newName)
  }

  override Void remove(Str name)
  {
    fb.delete("${name}.xeto")
    libs.reload
  }

  private Spec doUpdate(Str name, Str body)
  {
    write(name, body)
    libs.reload
    return lib.spec(name)
  }

  private Void write(Str name, Str body)
  {
    buf := Buf()
    buf.capacity = name.size + 16 + body.size
    buf.print(name).print(": ").print(body)
    fb.write("${name}.xeto", buf)
  }
}

