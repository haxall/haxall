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
using xetom
using haystack

**
** LocalNamespace compiles its libs from a repo
**
const class LocalNamespace : MNamespace
{
  new make(LocalNamespaceInit init)
    : super(init.env, init.versions, null)
  {
    this.repo  = init.repo
    this.build = init.build
  }

  const LibRepo repo

  override Bool isRemote() { false }

  const [Str:File]? build

//////////////////////////////////////////////////////////////////////////
// Loading
//////////////////////////////////////////////////////////////////////////


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


**************************************************************************
** LocalNamespaceInit
**************************************************************************

const class LocalNamespaceInit
{
  new make(XetoEnv env, LibRepo repo, LibVersion[] versions, [Str:File]? build := null)
  {
    this.env      = env
    this.repo     = repo
    this.versions = versions
    this.build    = build
  }

  const MEnv env
  const LibRepo repo
  const LibVersion[] versions
  const [Str:File]? build
}

