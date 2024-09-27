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
  static const DocTypeGraph empty := make(DocTypeRef[,], null)

  ** Constructor
  new make(DocTypeRef[] types, Int[][]? edges)
  {
    this.types = types
    this.edges = edges
  }

  ** List of all types in the inheritance graph
  const DocTypeRef[] types

  ** This is a list of edges for each type aligned by list index
  ** Used only for supertypes, not subtypes
  const Int[][]? edges

  ** Encode to a JSON object tree
  [Str:Obj]? encode()
  {
    if (types.isEmpty) return null
    acc := Str:Obj[:]
    acc.ordered = true
    acc["types"] = types.map |x| { x.encode }
    acc.addNotNull("edges", edges)
    return acc
  }

  ** Decode from JSON object tree
  static DocTypeGraph decode([Str:Obj]? obj)
  {
    if (obj == null) return empty
    types := ((List)obj.getChecked("types")).map |x| { DocTypeRef.decode(x) }
    edges := obj["edges"]
    return make(types, edges)
  }
}

