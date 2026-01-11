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

  new make(MNamespace ns, InStream in, Spec? spec := null, Dict? opts := null)
  {
    this.ns = ns
    this.in = in
    this.spec = spec
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  Obj? readVal()
  {
    x := JsonInStream(in).readJson
    return convert(ns, x, spec)
  }

  private static Obj? convert(MNamespace ns, Obj? x, Spec? spec)
  {
    if (x is Str)
    {
      if ((spec == null) || (spec.qname == "sys::Str"))
        return x
      else
        return spec.binding.decodeScalar(x)
    }
    else if (x is Map)  return convertMap(ns, x, spec)
    else if (x is List) return convertList(ns, x)

    // null, Bool, Int, Float
    else return x
  }

  private static Dict convertMap(MNamespace ns, Str:Obj? map, Spec? spec)
  {
    if (spec == null)
    {
      if (map.containsKey("spec"))
        spec = ns.spec(map["spec"])
    }

    map.each |v, k|
    {
      // id doesn't have member entry
      if (k == "id")
      {
        map[k] = Ref.fromStr(v)
      }
      // anything else but "spec"
      else if (k != "spec")
      {
        x := convert(ns, v, spec.member(k))
        if (v !== x)
        {
          map[k] = x
        }
      }
    }

    return spec.binding.decodeDict(Etc.dictFromMap(map))
  }

  private static Obj[] convertList(MNamespace ns, Obj?[] ls)
  {
    ls.each |v, i|
    {
      x := convert(ns, v, null)
      if (v !== x)
        ls[i] = x
    }
    return ls
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private MNamespace ns
  private InStream in
  private Spec? spec
}

