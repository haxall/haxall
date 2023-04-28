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
using haystack::NA
using haystack::Remove
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
    this.registry = XetoRegistry(this)
    this.none     = Remove.val
    this.marker   = Marker.val
    this.na       = NA.val
    this.list0    = Obj?[,]
    this.dict0    = Etc.dict0
    this.factory  = XetoFactory()
    this.sysLib   = registry.load("sys")
    this.sys      = MSys(sysLib)
    this.dictSpec = sys.dict
  }

  const override XetoRegistry registry

  const override DataLib sysLib

  const MSys sys

  const XetoFactory factory

  const NilDataContext nilContext := NilDataContext()

  override const Obj marker

  override const Obj none

  override const Obj na

  const Obj?[] list0

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

  override XetoLib? lib(Str qname, Bool checked := true)
  {
    registry.load(qname, checked)
  }

  override XetoType? type(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")
    libName := qname[0..<colon]
    typeName := qname[colon+2..-1]
    type := lib(libName, false)?.slotOwn(typeName, false)
    if (type != null) return type
    if (checked) throw UnknownTypeErr("Unknown data type: $qname")
    return null
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

  override DataSpec derive(Str name, DataSpec base, DataDict meta, [Str:DataSpec]? slots := null)
  {
    XetoUtil.derive(this, name, base, meta, slots)
  }

  override Obj? instantiate(DataSpec spec, DataDict? opts := null)
  {
    XetoUtil.instantiate(this, spec, opts ?: dict0)
  }

  override DataLib compileLib(Str src, DataDict? opts := null)
  {
    qname := "temp" + compileCount.getAndIncrement

    if (!src.startsWith("pragma:"))
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

  override Obj? compileData(Str src, DataDict? opts := null)
  {
    c := XetoCompiler
    {
      it.env = this
      it.input = src.toBuf.toFile(`parse.xeto`)
      it.applyOpts(opts)
    }
    return c.compileData
  }

  override DataDict parsePragma(File file, DataDict? opts := null)
  {
    c := XetoCompiler
    {
      it.env = this
      it.input = file
      it.applyOpts(opts)
    }
    return c.parsePragma
  }

  override Bool specFits(DataSpec a, DataSpec b, DataDict? opts := null)
  {
    if (opts == null) opts = dict0
    explain := XetoUtil.optLog(opts, "explain")
    cx := nilContext
    if (explain == null)
      return Fitter(this, cx, opts).specFits(a, b)
    else
      return ExplainFitter(this, cx, opts, explain).specFits(a, b)
  }

  override Bool fits(DataContext cx, Obj? val, DataSpec spec, DataDict? opts := null)
  {
    if (opts == null) opts = dict0
    explain := XetoUtil.optLog(opts, "explain")
    if (explain == null)
      return Fitter(this, cx, opts).valFits(val, spec)
    else
      return ExplainFitter(this, cx, opts, explain).valFits(val, spec)
  }

  override Obj? queryWhile(DataContext cx, DataDict subject, DataSpec query, DataDict? opts, |DataDict->Obj?| f)
  {
    // TODO: redesign to use eachWhile
    acc := Query(this, cx, opts).query(subject, query)
    return acc.eachWhile(f)
  }

  override DataDict genAst(DataSpec spec, DataDict? opts := null)
  {
    own := opts != null && opts.has("own")
    return XetoUtil.genAst(this, spec, own)
  }

  override Void print(Obj? val, OutStream out := Env.cur.out, DataDict? opts := null)
  {
    Printer(this, out, opts ?: dict0).print(val)
  }

  override Void dump(OutStream out := Env.cur.out)
  {
    out.printLine("=== XetoEnv ===")
    out.printLine("Lib Path:")
    registry.libPath.eachr |x| { out.printLine("  $x.osPath") }
    max := registry.list.reduce(10) |acc, x| { x.qname.size.max(acc) }
    out.printLine("Installed Libs:")
    registry.list.each |entry|
    {
      out.print("  ").print(entry.qname.padr(max))
      if (entry.isSrc)
        out.print(" [SRC ").print(entry.srcDir.osPath)
      else
        out.print(" [").print(entry.zip.osPath)
      out.printLine("]")
    }
  }

  private const ConcurrentMap libs := ConcurrentMap()
  private const AtomicInt compileCount := AtomicInt()
}

**************************************************************************
** NilContext
**************************************************************************

@Js
internal const class NilDataContext : DataContext
{
  override DataDict? dataReadById(Obj id) { null }
  override Obj? dataReadAllEachWhile(Str filter, |DataDict->Obj?| f) { null }
}

