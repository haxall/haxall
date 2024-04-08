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
using haystack::Etc

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

  const LibRepo repo

//////////////////////////////////////////////////////////////////////////
// Loading
//////////////////////////////////////////////////////////////////////////

  override XetoLib doLoadSync(LibVersion v)
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

  override Void doLoadListAsync(LibVersion[] versions, |Err?, Obj[]?| f)
  {
    try
    {
      acc := Obj[,]
      acc.capacity = versions.size
      versions.each |version|
      {
        try
          acc.add(doLoadSync(version))
        catch (Err e)
          acc.add(e)
      }
      f(null, acc)
    }
    catch (Err e)
    {
      f(e, null)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Compiling
//////////////////////////////////////////////////////////////////////////

  override Lib compileLib(Str src, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0

    libName := "temp" + compileCount.getAndIncrement

    if (!src.startsWith("pragma:"))
      src = """pragma: Lib <
                  version: "0.0.0"
                  depends: { { lib: "sys" } }
                >
                """ + src

    c := XetoCompiler
    {
//      it.env     = this
      it.libName = libName
      it.input   = src.toBuf.toFile(`temp.xeto`)
      it.applyOpts(opts)
    }

    lib := c.compileLib

//    if (opts.has("register")) registry.addTemp(lib)

    return lib
  }

  override Obj? compileData(Str src, Dict? opts := null)
  {
    c := XetoCompiler
    {
//      it.env = this
      it.input = src.toBuf.toFile(`parse.xeto`)
      it.applyOpts(opts)
    }
    return c.compileData
  }

  private const AtomicInt compileCount := AtomicInt()
}

