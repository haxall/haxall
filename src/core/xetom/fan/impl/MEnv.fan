//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jul 2025  Brian Frank  Split out implementation
//

using concurrent
using util
using xeto
using haystack

**
** MEnv is the base for XetoEnv implementations.  We
** have a ServerEnv and ClientEnv.
**
@Js
abstract const class MEnv : XetoEnv
{
  static XetoEnv init()
  {
    if (Env.cur.isBrowser)
      return RemoteEnv()
    else
      return Slot.findMethod("xetoc::ServerEnv.initPath").call
  }

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

  override Str dictDis(Dict x)
  {
    Etc.dictToDis(x, null) ?: x.toStr
  }

  override Str dictToStr(Dict x)
  {
    Etc.dictToStr(x)
  }

  override Dict dictMap(Dict x, |Obj val, Str name->Obj| f)
  {
    acc := Str:Obj[:]
    x.each |v, n| { acc[n] = f(v, n) }
    return Etc.dictFromMap(acc)
  }

//////////////////////////////////////////////////////////////////////////
// Serialization
//////////////////////////////////////////////////////////////////////////

  override Void saveLibs(OutStream out, Lib[] libs)
  {
    XetoBinaryWriter(out).writeLibs(libs)
  }

  override LibVersion[] loadLibs(InStream in)
  {
    t1 := Duration.now
    acc := LibVersion[,]
    XetoBinaryReader(in).readLibs(this) |lib|
    {
      acc.add(RemoteLibVersion(lib.name, lib.version, lib.depends))
      libsByName.getOrAdd(lib.name, lib)
    }
    t2 := Duration.now
    Console.cur.info("Loaded $acc.size libs [" + (t2-t1).toLocale + "]")
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Cache
//////////////////////////////////////////////////////////////////////////

  ** Get the lib in the cache or try to comile it.
  ** Note: we only support one version of a lib right now!
  XetoLib getOrCompile(LibNamespace ns, LibVersion x)
  {
    // check cache
    name := x.name
    lib := libsByName.get(name) as Lib
    if (lib != null)
    {
      if (lib.version != x.version) throw Err("Matched lib versions $name.toCode: $lib.version != $x.version")
      return lib
    }

    // don't ever cache the special proj lib
    lib = compile(ns, x)
    if (name == XetoUtil.companionLibName) return lib

    return libsByName.getOrAdd(name, lib)
  }

  ** Lookup cached lib by name
  Lib? get(Str name, Bool checked := true)
  {
    lib := libsByName.get(name)
    if (lib != null) return lib
    if (checked) throw UnknownLibErr(name)
    return null
  }


  ** Clear the lib cache
  protected Void libCacheClear() { libsByName.clear }

  ** Lib cache keyed by lib name
  private const ConcurrentMap libsByName := ConcurrentMap()

//////////////////////////////////////////////////////////////////////////
// Compile
//////////////////////////////////////////////////////////////////////////

  ** Compile specific lib
  private XetoLib compile(MNamespace ns, LibVersion v)
  {
    build := ns.opts.get("build") as Str:File
    c := XetoCompiler.init
    {
      it.ns      = ns
      it.libName = v.name
      it.input   = v.file
      it.build   = build?.get(v.name)
    }
    return c.compileLib
  }

  ** Compile temp lib from source
  Lib compileTempLib(MNamespace ns, Str src, Dict opts)
  {
    libName := "temp" + tempCompileCount.getAndIncrement

    if (!src.startsWith("pragma:"))
      src = """pragma: Lib <
                  version: "0.0.0"
                  depends: { { lib: "sys" } }
                >
                """ + src

    c := XetoCompiler.init
    {
      it.ns      = ns
      it.libName = libName
      it.input   = src.toBuf.toFile(`temp.xeto`)
      it.applyOpts(opts)
    }

    return c.compileLib
  }

  ** Compile data
  Obj? compileData(MNamespace ns, Str src, Dict opts)
  {
    c := XetoCompiler.init
    {
      it.ns    = ns
      it.input = src.toBuf.toFile(`parse.xeto`)
      it.applyOpts(opts)
    }
    return c.compileData
  }

  private const AtomicInt tempCompileCount := AtomicInt()

//////////////////////////////////////////////////////////////////////////
// Build
//////////////////////////////////////////////////////////////////////////

  ** Run build thru this env (not really thread safe)
  LibNamespace build(LibVersion[] build)
  {
    // turn verions to lib depends
    buildAsDepends := build.map |v->LibDepend|
    {
      if (!v.isSrc) throw ArgErr("Not source lib: $v")
      return MLibDepend(v.name, LibDependVersions(v.version))
    }

    // solve dependency graph for full list of libs
    libs := repo.solveDepends(buildAsDepends)

    // build map of lib name to
    buildFiles := Str:File[:]
    build.each |v| { buildFiles[v.name] = XetoUtil.srcToLibZip(v) }

    // create namespace and force all libs to be compiled
    libCacheClear
    ns := MNamespace(this, libs, Etc.dict1("build", buildFiles))
    ns.libs

    // report which libs could not be compiled
    ns.versions.each |v|
    {
      if (ns.libStatus(v.name).isErr) echo("ERROR: could not compile $v.name.toCode")
    }

    return ns
  }

}

