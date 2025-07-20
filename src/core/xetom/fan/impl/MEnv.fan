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
      return BrowserEnv()
    else
      return Slot.findMethod("xetoc::ServerEnv.initPath").call
  }

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

  ** Get the lib in the cache or try to comile it
  XetoLib getOrCompile(LibNamespace ns, LibVersion v)
  {
    map.get(v.toStr) ?: map.getOrAdd(v.toStr, compile(ns, v))
  }

  ** Hook to to compile
  protected virtual XetoLib compile(LibNamespace ns, LibVersion v)
  {
    throw UnsupportedErr("Lib cannot be compiled, must be preloaded: $v")
  }

//////////////////////////////////////////////////////////////////////////
// Serialization
//////////////////////////////////////////////////////////////////////////

  override Void saveLibs(OutStream out, Lib[] libs)
  {
    XetoBinaryWriter(out).writeLibs(libs)
  }

  override Void loadLibs(InStream in)
  {
    libs := XetoBinaryReader(in).readLibs(this)
    libs.each |lib|
    {
      key := lib.version.toStr
      map.getOrAdd(key, lib)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const ConcurrentMap map := ConcurrentMap()
}

**************************************************************************
** JsEnv
**************************************************************************

**
** Browser client based environment
**
@Js
const class BrowserEnv : MEnv
{
  override LibRepo repo() { throw unavailErr() }

  override File homeDir() { throw unavailErr() }

  override File workDir() { throw unavailErr() }

  override File installDir() { throw unavailErr() }

  override File[] path() { throw unavailErr() }

  override Str:Str buildVars() { throw unavailErr() }

  override LibNamespace createNamespace(LibVersion[] libs) { throw unavailErr() }

  override LibNamespace createNamespaceFromNames(Str[] names) { throw unavailErr() }

  override LibNamespace createNamespaceFromData(Dict[] recs) { throw unavailErr() }

  override Str mode() { "browser" }

  override Str:Str debugProps() { Str:Obj[:] }

  override Void dump(OutStream out := Env.cur.out) {}

  static Err unavailErr() { Err("Not available in browser") }
}

