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
    this.gridSpec = ns.spec("sys::Grid")
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
    // If the spec is null, try to look it up
    if (spec == null)
    {
      if (dict.has("spec"))
        spec = ns.spec(dict->spec)
    }

    // Check for Grid special case
    if (spec == gridSpec)
      return convertGrid(ns, dict)

    members := (spec == null) ? null : spec.members
    map := Str:Obj[:]

    // each entry
    dict.each |v, k|
    {
      // id and spec are Refs (and they do not have member entries)
      if (k == "id" || k == "spec")
      {
        map[k] = Ref.fromStr(v)
      }
      // handle normally
      else
      {
        mspec := (members == null) ? null : members.get(k, false)
        map[k] = convert(ns, v, mspec)
      }
    }

    // convert to dict
    dict = Etc.dictFromMap(map)

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
    cols := (List) dict->cols
    cols.each |Dict col|
    {
      meta = col["meta"]
      if (meta == null)
        gb.addCol(col->name)
      else
        gb.addCol(col->name, convert(ns, meta, null))
    }

    // rows
    rows := (List) dict->rows
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
  private Spec gridSpec
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

