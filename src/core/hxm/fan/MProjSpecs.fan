//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jul 2025  Brian Frank  Creation
//

using concurrent
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
  }

  const MProjLibs libs

  override Lib lib()
  {
    libs.ns.lib("proj")
  }

  override Spec add(Str name, Str body)
  {
    if (lib.spec(name, false) != null) throw ArgErr("Spec already exists: $name")
    return doUpdate(name, body)
  }

  override Spec update(Str name, Str body)
  {
    lib.spec(name)
    return doUpdate(name, body)
  }

  override Void remove(Str name)
  {
    libs.fb.delete("${name}.xeto")
    libs.reload
  }

  private Spec doUpdate(Str name, Str body)
  {
    buf := Buf()
    buf.capacity = name.size + 16 + body.size
    buf.print(name).print(": ").printLine(body)
    libs.fb.write("${name}.xeto", buf)
    libs.reload
    return lib.spec(name)
  }
}

