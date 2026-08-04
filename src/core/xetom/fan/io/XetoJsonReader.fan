//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jan 2026  Mike Jarmy  Creation
//

using xeto
using haystack
using util

**
** XetoJsonReader
**
@Js
class XetoJsonReader
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, InStream in, Spec? rootSpec := null, Dict? opts := null)
  {
    this.ns = ns
    this.in = in
    this.rootSpec = rootSpec
    this.specs = XetoJsonSpec(ns)
    this.fidelity = XetoUtil.optFidelity(opts)
    this.lenient  = XetoUtil.optBool(opts, "lenient", false)
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  Obj? readVal()
  {
    x := XetoJsonInStream(in).readJson
    return convert(x, rootSpec)
  }

  private Obj? convert(Obj? x, Spec? spec)
  {
    if (x is Dict) return convertDict(x, spec)
    if (x is List) return convertList(x, spec)
    return convertScalar(x, spec)
  }

  private Obj convertDict(Dict dict, Spec? spec)
  {
    // if the spec is null, try to look it up
    if (spec == null)
    {
      specRef := dict["spec"]
      if (specRef != null)
        spec = ns.spec(specRef.toStr)
    }

    // check for Grid special case
    if (spec != null && spec.isGrid)
      return convertGrid(dict)

    // map dict pairs
    acc := Str:Obj[:]
    if (dict.isOrdered) acc.ordered = true
    dict.each |v, k|
    {
      // id and spec are Refs (and they do not have member entries)
      if (k == "id" || k == "spec")
        acc[k] = Ref.fromStr(v)
      else
        acc[k] = convert(v, specs.member(spec, k))
    }
    dict = Etc.dictFromMap(acc)

    // apply spec binding, if we are not haystack
    if ((spec != null) && (fidelity !== XetoFidelity.haystack))
      dict = spec.binding.decodeDict(dict)
    return dict
  }

  private Grid convertGrid(Dict dict)
  {
    gb := GridBuilder()

    // meta
    meta := dict["meta"]
    if (meta != null)
      gb.setMeta(convert(meta, null))

    // cols
    cols := dict["cols"] as Obj?[] ?: throw Err("Grid missing 'cols' list")
    cols.each |Dict col|
    {
      meta = col["meta"]
      if (meta == null)
        gb.addCol(col->name)
      else
        gb.addCol(col->name, convert(meta, null))
    }

    // rows
    rows := dict["rows"] as Obj?[] ?: throw Err("Grid missing 'rows' list")
    rows.each |r| { gb.addDictRow(convert(r, null)) }

    // done
    return gb.toGrid
  }

  private Obj?[] convertList(Obj?[] from, Spec? spec)
  {
    // a list spec need not declare 'of'; without it the items are untyped
    of := specs.listOf(spec)

    if (from.contains(null))
      return from.map |Obj? v->Obj?| { convert(v, of) }
    else
      return from.map |Obj v->Obj| { convert(v, of) }
  }

  private Obj? convertScalar(Obj? x, Spec? spec)
  {
    if (x is Str)
    {
      if ((spec == null) && (x == "✓")) return Marker.val

      // haystack fidelity only decodes against a haystack type
      if ((spec != null) &&
          ((fidelity !== XetoFidelity.haystack) || spec.type.isHaystack))
        return spec.binding.decodeScalar(x)

      return x
    }

    // haystack fidelity has no Int or Float, only Number
    if (fidelity === XetoFidelity.haystack)
    {
      if (x is Int) return Number.makeInt(x)
      if (x is Float) return Number.make(x)
    }

    return x
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const MNamespace ns
  private InStream in
  private Spec? rootSpec
  private XetoJsonSpec specs
  private XetoFidelity fidelity

  ** Degrade a position to untyped instead of raising when its value cannot
  ** be decoded: unparseable text, unresolvable spec ref, malformed box.
  ** Does not gate self-description: a box or a JSON native form overriding
  ** the context spec is always legal and never an error.
  private Bool lenient
}

**************************************************************************
** XetoJsonInStream
**************************************************************************

@Js
internal class XetoJsonInStream : JsonInStream
{
  internal new make(InStream in) : super(in) {}

  override Obj transformObj(Str:Obj? obj) { Etc.makeDict(obj) }
}

