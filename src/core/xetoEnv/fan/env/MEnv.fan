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
abstract const class MEnv : XetoEnv
{
  new make(NameTable names, MRegistry registry, |This|? f)
  {
    this.names       = names
    this.none        = Remove.val
    this.marker      = Marker.val
    this.na          = NA.val
    this.list0       = Obj?[,]
    this.specSpecRef = haystack::Ref("sys::Spec", null)
    this.libSpecRef  = haystack::Ref("sys::Lib", null)
    this.registryRef = registry
    if (f != null) f(this)
    this.sysLib      = registry.loadSync("sys")
    this.sys         = MSys(sysLib)
    this.dictSpec    = sys.dict
  }

  const override Lib sysLib

  const MSys sys

  override const NameTable names

  const MFactories factories := MFactories()

  override MRegistry registry() { registryRef }

  const MRegistry registryRef

  internal const NilContext nilContext := NilContext()

  const Obj marker

  const Obj none

  const Obj na

  const Obj?[] list0

  const Ref specSpecRef

  const Ref libSpecRef

  const override Spec dictSpec

  Dict dict0() { Etc.dict0 }

  Dict dictMap(Str:Obj map) { Etc.dictFromMap(map) }

  Ref ref(Str id, Str? dis := null) { haystack::Ref.make(id, dis) }

  override Spec? specOf(Obj? val, Bool checked := true)
  {
    if (val == null) return sys.none

    // dict handling
    dict := val as Dict
    if (dict != null)
    {
      specRef := dict["spec"] as Ref
      if (specRef == null) return dictSpec
      return spec(specRef.id, checked)
    }

    // look in Fantom class hiearchy
    type := val as Type ?: val.typeof
    for (Type? p := type; p != null; p = p.base)
    {
      spec := factories.typeToSpec(p)
      if (spec != null) return spec
      spec = p.mixins.eachWhile |m| { factories.typeToSpec(m) }
      if (spec != null) return spec
    }

    // fallbacks
    if (val is List) return sys.list
    if (type.fits(Grid#)) return lib("ph").type("Grid")

    // cannot map to spec
    if (checked) throw UnknownSpecErr("No spec mapped for '$type'")
    return null
  }

  override XetoLib? lib(Str name, Bool checked := true)
  {
    registry.loadSync(name, checked)
  }

  override Void libAsync(Str name, |Err?, Lib?| f)
  {
    registry.loadAsync(name, f)
  }

  override Void libAsyncList(Str[] names, |Err?| f)
  {
    registry.loadAsyncList(names, f)
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

    spec := lib(libName, false)?.spec(names.first, false)
    for (i:=1; spec != null && i<names.size; ++i)
      spec = spec.slot(names[i], false)

    if (spec != null) return spec
    if (checked) throw UnknownSpecErr(qname)
    return null
  }

  override Dict? instance(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")

    libName := qname[0..<colon]
    name := qname[colon+2..-1]

    instance := lib(libName, false)?.instance(name, false)

    if (instance != null) return instance
    if (checked) throw haystack::UnknownRecErr(qname)
    return null
  }

  override Obj? instantiate(Spec spec, Dict? opts := null)
  {
    XetoUtil.instantiate(this, spec, opts ?: dict0)
  }

  override Dict[] compileDicts(Str src, Dict? opts := null)
  {
    val := compileData(src, opts)
    if (val is List) return ((List)val).map |x->Dict| { x as Dict ?: throw IOErr("Expecting Xeto list of dicts, not ${x?.typeof}") }
    if (val is Dict) return Dict[val]
    throw IOErr("Expecting Xeto dict data, not ${val?.typeof}")
  }

  override Void writeData(OutStream out, Obj val, Dict? opts := null)
  {
    Printer(this, out, opts ?: dict0).xetoTop(val)
  }

  override Spec? choiceOf(Dict instance, Spec choice, Bool checked := true)
  {
    XetoUtil.choiceOf(this, instance, choice, checked)
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

}

**************************************************************************
** NilContext
**************************************************************************

@Js
internal const class NilContext : XetoContext
{
  static const NilContext val := make
  override Dict? xetoReadById(Obj id) { null }
  override Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f) { null }
  override Bool xetoIsSpec(Str spec, Dict rec) { false }
}

