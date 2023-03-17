//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using concurrent
using util
using data
using haystack::Etc
using haystack::Marker
using haystack::Grid
using haystack::UnknownSpecErr

**
** Xeto DataEnv implementation
**
@Js
internal const class XetoEnv : DataEnv
{
  new make()
  {
    this.libMgr = XetoLibMgr(this)
    this.marker = Marker.val
    this.dict0 = Etc.dict0
    this.factory = XetoFactory()
    this.sysLib = libMgr.load("sys")
    this.sys = MSys(sysLib)
    this.dictSpec = sys.dict
  }

  const XetoLibMgr libMgr

  const override DataLib sysLib

  const MSys sys

  const XetoFactory factory

  override const Obj marker

  override const DataSpec dictSpec

  const override DataDict dict0

  override DataDict dict1(Str n, Obj v) { Etc.dict1(n, v) }

  override DataDict dict2(Str n0, Obj v0, Str n1, Obj v1) {  Etc.dict2(n0, v0, n1, v1) }

  override DataDict dict3(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2) {  Etc.dict3(n0, v0, n1, v1, n2, v2)  }

  override DataDict dict4(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3) { Etc.dict4(n0, v0, n1, v1, n2, v2, n3, v3) }

  override DataDict dict5(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4) { Etc.dict5(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4) }

  override DataDict dict6(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4, Str n5, Obj v5) { Etc.dict6(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5) }

  override DataDict dictMap(Str:Obj map, DataSpec? spec := null)
  {
    dict := Etc.dictFromMap(map)
    if (spec == null || spec === dictSpec) return dict
    return MDict(dict, spec)
  }

  override DataDict dict(Obj? val)
  {
    if (val == null) return dict0
    if (val is DataDict) return val
    map := val as Str:Obj ?: throw ArgErr("Unsupported dict arg: $val.typeof")
    return dictMap(map, null)
  }

  override DataType? typeOf(Obj? val, Bool checked := true)
  {
    if (val == null) return sys.none
    item := factory.fromFantom[val.typeof]
    if (item != null) return type(item.xeto)
    if (val is DataDict) return ((DataDict)val).spec.type
    if (val is List) return sys.list
    if (val is Grid) return lib("ph").slotOwn("Grid")
    if (checked) throw UnknownTypeErr("No DataType mapped for '$val.typeof'")
    return null
  }

  override Str[] libsInstalled() { libMgr.installed }

  override Bool isLibLoaded(Str qname) { libMgr.isLoaded(qname) }

  override XetoLib? lib(Str qname, Bool checked := true) { libMgr.load(qname, checked) }

  override Void print(Obj? val, OutStream out := Env.cur.out, Obj? opts := null)
  {
    Printer(this, out, dict(opts)).print(val)
  }

  override DataLib compileLib(Str src, [Str:Obj]? opts := null)
  {
    qname := "temp" + compileCount.getAndIncrement

    src = """pragma: Lib <
                version: "0"
                depends: { { lib: "sys" } }
              >
              """ + src

    c := XetoCompiler
    {
      it.env = this
      it.qname = qname
      it.input = src.toBuf.toFile(`temp.xeto`)
      it.applyOpts(opts)
    }
    return c.compileLib
  }

  override Obj? compileData(Str src, [Str:Obj]? opts := null)
  {
    c := XetoCompiler
    {
      it.env = this
      it.input = src.toBuf.toFile(`parse.xeto`)
      it.applyOpts(opts)
    }
    return c.compileData
  }

  override Bool specFits(DataSpec a, DataSpec b, [Str:Obj]? opts := null)
  {
    explain := opts?.get("explain")
    if (explain == null)
      return Fitter(this, true).specFits(a, b)
    else
      return ExplainFitter(this, explain).specFits(a, b)
  }

  override Bool fits(Obj? val, DataSpec spec, [Str:Obj]? opts := null)
  {
    explain := opts?.get("explain")
    if (explain == null)
      return Fitter(this, true).valFits(val, spec)
    else
      return ExplainFitter(this, explain).valFits(val, spec)
  }

  override DataSpec derive(Str name, DataSpec base, DataDict meta, [Str:DataSpec]? slots := null)
  {
    XetoUtil.derive(this, name, base, meta, slots)
  }

  override XetoSpec? spec(Str qname, Bool checked := true)
  {
    colon := qname.index("::")
    if (colon == null) return lib(qname, checked)

    libName := qname[0..<colon]
    names := qname[colon+2..-1].split('.', false)

    DataSpec? spec := lib(libName, false)
    if (spec != null)
    {
      for (i:=0; i<names.size; ++i)
      {
        spec = spec.slot(names[i], false)
        if (spec == null) break
      }
    }

    if (spec != null) return spec
    if (checked) throw UnknownSpecErr(qname)
    return null
  }

  override XetoType? type(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")
    libName := qname[0..<colon]
    typeName := qname[colon+2..-1]
    return lib(libName, checked)?.slotOwn(typeName, checked)
  }

  override Void dump(OutStream out := Env.cur.out)
  {
    out.printLine("=== XetoEnv ===")
    out.printLine("Lib Path:")
    libMgr.path.each |x| { out.printLine("  $x.osPath") }
    max := libsInstalled.reduce(10) |acc, x| { x.size.max(acc) }
    out.printLine("Installed Libs:")
    libMgr.installed.each |x| { out.printLine("  " + x.padr(max) + " [" + libMgr.libDir(x, true).osPath + "]") }
  }

  private const ConcurrentMap libs := ConcurrentMap()
  private const AtomicInt compileCount := AtomicInt()
}

