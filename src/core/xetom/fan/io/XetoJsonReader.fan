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
    // todo
      if ((spec == null) || (spec.qname == "sys::Str"))
        return x
      else
        return spec.binding.decodeScalar(x)
    }
    else if (x is Map)  return convertMap(ns, x, spec)
    else if (x is List) return convertList(ns, x, spec)

    // null, Bool, Int, Float
    else return x
  }

  private static Dict convertMap(MNamespace ns, Str:Obj? map, Spec? spec)
  {
    // If the spec isn't specified, try to look it up within the map
    if (spec == null)
    {
      if (map.containsKey("spec"))
        spec = ns.spec(map["spec"])
    }

    map.each |v, k|
    {
      // id and spec are Refs (and they do not have member entries)
      if (k == "id" || k == "spec")
      {
        map[k] = Ref.fromStr(v)
      }
      // handle normally
      else
      {
        // use member spec to convert value
        if (spec != null && spec.members.has(k)) // don't use has
        {
          x := convert(ns, v, spec.members.get(k)) // look members up once
          if (v !== x)
          {
            map[k] = x
          }
        }
        // convert un-typed nested maps
        else if (v is Map)
        {
          x := convertMap(ns, v, null)
          if (v !== x)
          {
            map[k] = x
          }
        }
        // TODO list also
      }
    }

    // convert to dict
    dict := Etc.dictFromMap(map)
    if (spec != null)
      dict = spec.binding.decodeDict(dict)
    return dict
  }

  private static Obj[] convertList(MNamespace ns, Obj?[] ls, Spec? spec)
  {
    of := spec.of()

    ls.each |v, i|
    {
      x := convert(ns, v, of)
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

