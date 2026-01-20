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

// TODO fidelity flag

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
    if      (x is Dict) return convertDict(ns, x, spec)
    else if (x is List) return convertList(ns, x, spec)
    else                return convertScalar(ns, x, spec)
  }

  private Dict convertDict(MNamespace ns, Dict dict, Spec? spec)
  {
    // If the spec is null, try to look it up
    if (spec == null)
    {
      if (dict.has("spec"))
        spec = ns.spec(dict->spec)
    }

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

  private Obj[] convertList(MNamespace ns, Obj?[] ls, Spec? spec)
  {
    of := (spec == null) ? null : spec.of()

    ls.each |v, i|
    {
      ls[i] = convert(ns, v, of)
    }
    return ls
  }

  private Obj convertScalar(MNamespace ns, Obj x, Spec? spec)
  {
    if (fidelity === XetoFidelity.haystack)
    {
      if (x is Str)
      {
        if ((spec != null) && spec.type.isHaystack)
          return spec.binding.decodeScalar(x)
      }
      else if (x is Int) return Number.makeInt(x)
      else if (x is Float) return Number.make(x)
    }
    else
    {
      if (x is Str)
      {
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

  override Obj transformObj(Str:Obj? obj) { return Etc.makeDict(obj) }
}

