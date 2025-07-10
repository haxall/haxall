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
    : super(init.base, init.names, init.versions, null)
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


**************************************************************************
** LocalNamespaceInit
**************************************************************************

const class LocalNamespaceInit
{
  new make(LibRepo repo, LibVersion[] versions, MNamespace? base := null, NameTable names := NameTable(), [Str:File]? build := null)
  {
    this.repo     = repo
    this.versions = versions
    this.base     = base
    this.names    = names
    this.build    = build
  }

  const LibRepo repo
  const LibVersion[] versions
  const MNamespace? base
  const NameTable names
  const [Str:File]? build
}

