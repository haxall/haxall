//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetoEnv

**
** LocalNamespace compiles its libs from a repo
**
const class LocalNamespace : MNamespace
{
  new make(NameTable names, LibVersion[] versions, LibRepo repo)
    : super(names, versions)
  {
    this.repo = repo
  }

  override XetoLib loadSync(LibVersion v)
  {
    /* TODO
    c := XetoCompiler
    {
      it.env     = XetoEnv.cur
      it.libName = v.name
      it.input   = v.file
      //it.zipOut  = entry.zip
      //it.build   = build
    }
    return c.compileLib
    */
    return XetoEnv.cur.lib(v.name)
  }

  override Void loadAsync(LibVersion v, |Err?, XetoLib?| f)
  {
    try
      f(null, loadSync(v))
    catch (Err e)
      f(e, null)
  }

  const LibRepo repo
}

