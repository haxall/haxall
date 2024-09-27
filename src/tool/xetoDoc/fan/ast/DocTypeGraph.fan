//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Sep 2024  Brian Frank  Creation
//

using xetoEnv

**
** DocTypeGraph models supertype/subtype inheritance graph of a type
**
@Js
const class DocTypeGraph
{
  ** Empty list of types
  static const DocTypeGraph empty := make(DocTypeRef[,])

  ** Constructor
  new make(DocTypeRef[] types)
  {
    this.types = types
  }

  ** List of all types in the inheritance graph
  const DocTypeRef[] types

  ** Encode to a JSON object tree
  [Str:Obj]? encode()
  {
    if (types.isEmpty) return null
    acc := Str:Obj[:]
    acc.ordered = true
    acc["types"] = types.map |x| { x.encode }
    return acc
  }

  ** Decode from JSON object tree
  static DocTypeGraph decode([Str:Obj]? obj)
  {
    if (obj == null) return empty
    types := ((List)obj.getChecked("types")).map |x| { DocTypeRef.decode(x) }
    return make(types)
  }
}

