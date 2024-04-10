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
  new make(NameTable names, LibVersion[] versions, LibRepo repo, [Str:File]? build)
    : super(names, versions, null)
  {
    this.repo  = repo
    this.build = build
  }

  const LibRepo repo

  override Bool isRemote() { false }

  const [Str:File]? build

//////////////////////////////////////////////////////////////////////////
// Loading
//////////////////////////////////////////////////////////////////////////

  override XetoLib doLoadSync(LibVersion v)
  {
    c := XetoCompiler
    {
      it.ns      = this
      it.libName = v.name
      it.input   = v.file
      it.build   = this.build?.get(v.name)
    }
    return c.compileLib
  }

  override Void doLoadAsync(LibVersion version, |Err?, Obj?| f)
  {
    try
      f(null, doLoadSync(version))
    catch (Err e)
      f(null, e)
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
      it.ns      = this
      it.libName = libName
      it.input   = src.toBuf.toFile(`temp.xeto`)
      it.applyOpts(opts)
    }

    return c.compileLib
  }

  override Obj? compileData(Str src, Dict? opts := null)
  {
    c := XetoCompiler
    {
      it.ns    = this
      it.input = src.toBuf.toFile(`parse.xeto`)
      it.applyOpts(opts)
    }
    return c.compileData
  }

  private const AtomicInt compileCount := AtomicInt()
}

