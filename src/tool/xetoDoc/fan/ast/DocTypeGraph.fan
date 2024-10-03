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
  new make(DocTypeRef[] types, DocTypeGraphEdge[]? edges)
  {
    this.types = types
    this.edges = edges
  }

  ** List of all types in the inheritance graph
  const DocTypeRef[] types

  ** This is a list of edges for each type aligned by list index
  ** Used only for supertypes, not subtypes
  const DocTypeGraphEdge[]? edges

  ** Encode to a JSON object tree
  [Str:Obj]? encode()
  {
    if (types.isEmpty) return null
    acc := Str:Obj[:]
    acc.ordered = true
    acc["types"] = types.map |x| { x.encode }
    acc.addNotNull("edges", DocTypeGraphEdge.encodeList(edges))
    return acc
  }

  ** Decode from JSON object tree
  static DocTypeGraph decode([Str:Obj]? obj)
  {
    if (obj == null) return empty
    types := ((List)obj.getChecked("types")).map |x| { DocTypeRef.decode(x) }
    edges := DocTypeGraphEdge.decodeList(obj["edges"])
    return make(types, edges)
  }
}

**************************************************************************
** DocTypeGraphEdge
**************************************************************************

@Js
const class DocTypeGraphEdge
{
  ** Edge for sys::Obj
  static const DocTypeGraphEdge obj := make(DocTypeGraphEdgeMode.obj, Int[,])

  ** Constructor
  new make(DocTypeGraphEdgeMode mode, Int[] types)
  {
    this.mode  = mode
    this.types = types
  }

  ** Type of edge in the graph
  const DocTypeGraphEdgeMode mode

  ** Type index or index this edge references
  const Int[] types

  ** Encode
  override Str toStr() { encode }

  ** Encode list of edges
  static Str[]? encodeList(DocTypeGraphEdge[]? list)
  {
    if (list == null) return null
    return list.map |x| { x.encode }
  }

  ** Encode to string
  Str encode()
  {
    s := StrBuf()
    s.capacity = mode.name.size + 2*types.size
    s.add(mode)
    types.each |index| { s.addChar(' ').add(index) }
    return s.toStr
  }

  ** Encode list of edges
  static DocTypeGraphEdge[]? decodeList(Str[]? list)
  {
    if (list == null) return null
    return list.map |x| { decode(x) }
  }

  ** Decode from string
  static DocTypeGraphEdge decode(Str s)
  {
    try
    {
      toks := s.split
      mode := DocTypeGraphEdgeMode.fromStr(toks[0])
      types := toks[1..-1].map |tok| { tok.toInt }
      return make(mode, types)
    }
    catch(Err e) throw ParseErr("DocTypeGraphEdge: $s")
  }

}

**************************************************************************
** DocTypeGraphEdgeMode
**************************************************************************

@Js
enum class DocTypeGraphEdgeMode
{
  obj,
  base,
  and,
  or
}

