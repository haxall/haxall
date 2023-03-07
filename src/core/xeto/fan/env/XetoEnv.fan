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

**
** Xeto DataEnv implementation
**
@Js
internal const class XetoEnv : DataEnv
{
  new make()
  {
    this.libMgr = XetoLibMgr(this)
    this.emptyDict = MDict(Str:Obj[:], null)
    this.factory = XetoFactory()
    this.sys = MSys(libMgr.load("sys"))
  }

  const XetoLibMgr libMgr

  const MSys sys

  const XetoFactory factory

  override Obj marker() { factory.marker }

  const override MDict emptyDict

  override DataType? typeOf(Obj? val, Bool checked := true)
  {
    if (val == null) return sys.none
    item := factory.fromFantom[val.typeof]
    if (item != null) return type(item.xeto)
    if (val is DataDict) return ((DataDict)val).spec.type
    if (checked) throw UnknownTypeErr("No DataType mapped for '$val.typeof'")
    return null
  }

  override DataSpec dictSpec() { sys.dict }

  override DataDict dict(Obj? val, DataSpec? spec := null)
  {
    if (val == null) return emptyDict
    if (val is DataDict) return val
    map := val as Str:Obj? ?: throw ArgErr("Unsupported dict arg: $val.typeof")
    if (map.isEmpty)
    {
      if (spec == null || spec === ((MSys?)sys)?.dict) return emptyDict
    }
    return MDict(map, spec)
  }

  override Str[] libsInstalled() { libMgr.installed }

  override Bool isLibLoaded(Str qname) { libMgr.isLoaded(qname) }

  override XetoLib? lib(Str qname, Bool checked := true) { libMgr.load(qname, checked) }

  override Void print(Obj? val, OutStream out := Env.cur.out, Obj? opts := null)
  {
    Printer(this, out, dict(opts)).print(val)
  }

  override DataLib compileLib(Str src)
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
    }
    return c.compileLib
  }

  override Obj? compileData(Str src)
  {
    c := XetoCompiler
    {
      it.env = this
      it.input = src.toBuf.toFile(`parse.xeto`)
    }
    return c.compileData
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

