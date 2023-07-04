//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack::Etc
using haystack::Marker
using haystack::NA
using haystack::Remove
using haystack::Grid
using haystack::Symbol
using haystack::UnknownSpecErr

**
** XetoEnv implementation
**
@Js
internal const class MEnv : XetoEnv
{
  new make()
  {
    this.registry = MRegistry(this)
    this.none     = Remove.val
    this.marker   = Marker.val
    this.na       = NA.val
    this.list0    = Obj?[,]
    this.dict0    = Etc.dict0
    this.sysLib   = registry.load("sys")
    this.sys      = MSys(sysLib)
    this.dictSpec = sys.dict
  }

  const override MRegistry registry

  const override Lib sysLib

  const MSys sys

  const MFactories factories := MFactories()

  const NilContext nilContext := NilContext()

  override const Obj marker

  override const Obj none

  override const Obj na

  const Obj?[] list0

  override const Spec dictSpec

  const override Dict dict0

  override Dict dict1(Str n, Obj v) { Etc.dict1(n, v) }

  override Dict dict2(Str n0, Obj v0, Str n1, Obj v1) {  Etc.dict2(n0, v0, n1, v1) }

  override Dict dict3(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2) {  Etc.dict3(n0, v0, n1, v1, n2, v2)  }

  override Dict dict4(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3) { Etc.dict4(n0, v0, n1, v1, n2, v2, n3, v3) }

  override Dict dict5(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4) { Etc.dict5(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4) }

  override Dict dict6(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4, Str n5, Obj v5) { Etc.dict6(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5) }

  override Dict dictMap(Str:Obj map, Spec? spec := null)
  {
    dict := Etc.dictFromMap(map)
    if (spec == null || spec === dictSpec) return dict
    return MDict(dict, spec)
  }

  override Dict dict(Obj? val)
  {
    if (val == null) return dict0
    if (val is Dict) return val
    map := val as Str:Obj ?: throw ArgErr("Unsupported dict arg: $val.typeof")
    return dictMap(map, null)
  }

  override Spec? typeOf(Obj? val, Bool checked := true)
  {
    if (val == null) return sys.none

    // direct lookup by type
    type := val.typeof
    spec := factories.typeToSpec(type)
    if (spec != null) return spec

    // some special lookup
    if (val is Dict) return ((Dict)val).spec.type
    if (val is List) return sys.list

    // walk up type hiearchy (classes only)
    for (Type? p := type.base; p != null; p = p.base)
    {
      spec = factories.typeToSpec(p)
      if (spec != null) return spec
    }

    // fallbacks
    if (val is Grid) return lib("ph").type("Grid")

    // cannot map to spec
    if (checked) throw UnknownSpecErr("No spec mapped for '$type'")
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
    type := lib(libName, false)?.type(typeName, false)
    if (type != null) return type
    if (checked) throw UnknownSpecErr("Unknown data type: $qname")
    return null
  }

  override XetoSpec? spec(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")

    libName := qname[0..<colon]
    names := qname[colon+2..-1].split('.', false)

    spec := lib(libName, false)?.type(names.first, false)
    for (i:=1; spec != null && i<names.size; ++i)
      spec = spec.slot(names[i], false)

    if (spec != null) return spec
    if (checked) throw UnknownSpecErr(qname)
    return null
  }

  override Spec derive(Str name, Spec base, Dict meta, [Str:Spec]? slots := null)
  {
    XetoUtil.derive(this, name, base, meta, slots)
  }

  override Obj? instantiate(Spec spec, Dict? opts := null)
  {
    XetoUtil.instantiate(this, spec, opts ?: dict0)
  }

  override Lib compileLib(Str src, Dict? opts := null)
  {
    libName := "temp" + compileCount.getAndIncrement

    if (!src.startsWith("pragma:"))
      src = """pragma: Lib <
                  version: "0.0.0"
                  depends: { { lib: "sys" } }
                >
                """ + src

    c := XetoCompiler
    {
      it.env     = this
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
      it.env = this
      it.input = src.toBuf.toFile(`parse.xeto`)
      it.applyOpts(opts)
    }
    return c.compileData
  }

  override Dict parsePragma(File file, Dict? opts := null)
  {
    c := XetoCompiler
    {
      it.env = this
      it.input = file
      it.applyOpts(opts)
    }
    return c.parsePragma
  }

  override LibDependVersions parseLibDependVersions(Str s, Bool checked)
  {
    MLibDependVersions.fromStr(s, checked)
  }

  override Bool specFits(Spec a, Spec b, Dict? opts := null)
  {
    if (opts == null) opts = dict0
    explain := XetoUtil.optLog(opts, "explain")
    cx := nilContext
    if (explain == null)
      return Fitter(this, cx, opts).specFits(a, b)
    else
      return ExplainFitter(this, cx, opts, explain).specFits(a, b)
  }

  override Bool fits(XetoContext cx, Obj? val, Spec spec, Dict? opts := null)
  {
    if (opts == null) opts = dict0
    explain := XetoUtil.optLog(opts, "explain")
    if (explain == null)
      return Fitter(this, cx, opts).valFits(val, spec)
    else
      return ExplainFitter(this, cx, opts, explain).valFits(val, spec)
  }

  override Obj? queryWhile(XetoContext cx, Dict subject, Spec query, Dict? opts, |Dict->Obj?| f)
  {
    // TODO: redesign to use eachWhile
    acc := Query(this, cx, opts).query(subject, query)
    return acc.eachWhile(f)
  }

  override Dict genAst(Obj libOrSpec, Dict? opts := null)
  {
    if (opts == null) opts = dict0
    isOwn := opts.has("own")
    if (libOrSpec is Lib)
      return XetoUtil.genAstLib(this, libOrSpec, isOwn, opts)
    else
      return XetoUtil.genAstSpec(this, libOrSpec, isOwn, opts)
  }

  override Void print(Obj? val, OutStream out := Env.cur.out, Dict? opts := null)
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
internal const class NilContext : XetoContext
{
  override Dict? xetoReadById(Obj id) { null }
  override Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f) { null }
}

