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
    this.fidelity = XetoUtil.optFidelity(opts)
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  Obj? readVal()
  {
    x := XetoJsonInStream(in).readJson
    return convert(ns, x, rootSpec)
  }

  private Obj? convert(MNamespace ns, Obj? x, Spec? spec)
  {
    if (x is Dict) return convertDict(ns, x, spec)
    if (x is List) return convertList(ns, x, spec)
    return convertScalar(ns, x, spec)
  }

  private Obj convertDict(MNamespace ns, Dict dict, Spec? spec)
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
      return convertGrid(ns, dict)

    members := (spec == null) ? null : spec.members

    // map dict pairs
    dict = dict.map |v, k|
    {
      // id and spec are Refs (and they do not have member entries)
      if (k == "id" || k == "spec") return Ref.fromStr(v)

      // handle normally
      mspec := (members == null) ? null : members.get(k, false)
      return convert(ns, v, mspec)
    }

    // apply spec binding, if we are not haystack
    if ((spec != null) && (fidelity !== XetoFidelity.haystack))
      dict = spec.binding.decodeDict(dict)
    return dict
  }

  private Grid convertGrid(MNamespace ns, Dict dict)
  {
    gb := GridBuilder()

    // meta
    meta := dict["meta"]
    if (meta != null)
      gb.setMeta(convert(ns, meta, null))

    // cols
    cols := dict["cols"] as Obj?[] ?: throw Err("Grid missing 'cols' list")
    cols.each |Dict col|
    {
      meta = col["meta"]
      if (meta == null)
        gb.addCol(col->name)
      else
        gb.addCol(col->name, convert(ns, meta, null))
    }

    // rows
    rows := dict["rows"] as Obj?[] ?: throw Err("Grid missing 'rows' list")
    rows.each |r| { gb.addDictRow(convert(ns, r, null)) }

    // done
    return gb.toGrid
  }

  private Obj?[] convertList(MNamespace ns, Obj?[] from, Spec? spec)
  {
    of := (spec == null) ? null : spec.of()

    if (from.contains(null))
      return from.map |Obj? v->Obj?| { convert(ns, v, of) }
    else
      return from.map |Obj v->Obj| { convert(ns, v, of) }
  }

  private Obj? convertScalar(MNamespace ns, Obj? x, Spec? spec)
  {
    if (fidelity === XetoFidelity.haystack)
    {
      if (x is Str)
      {
        if ((spec == null) && (x == "✓"))
          return Marker.val
        if ((spec != null) && spec.type.isHaystack)
          return spec.binding.decodeScalar(x)
      }
      if (x is Int) return Number.makeInt(x)
      if (x is Float) return Number.make(x)
    }
    else
    {
      if (x is Str)
      {
        if ((spec == null) && (x == "✓"))
          return Marker.val
        if (spec != null)
          return spec.binding.decodeScalar(x)
      }
    }

    return x
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private MNamespace ns
  private InStream in
  private Spec? rootSpec
  private XetoFidelity fidelity
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

