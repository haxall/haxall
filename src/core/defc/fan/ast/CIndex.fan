//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jul 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

using haystack
using def

**
** Index of all definitions
**
class CIndex
{
  internal new make(|This| f)
  {
    f(this)
  }

  ** Libs sorted by name
  CLib[] libs

  ** Features sorted by name
  once CDef[] features()
  {
    defs.findAll |def|
    {
      def.type.isTag &&
      def.isFeature &&
      def !== etc.feature
    }.ro
  }

  ** All defs sorted by symbol name
  CDef[] defs

  ** Lookup def by symbol
  CDef? def(Str symbol, Bool checked := true)
  {
    def := defsMap[symbol]
    if (def != null) return def
    if (checked) throw UnknownDefErr(symbol)
    return null
  }

  ** Quick access to various defs
  CIndexEtc etc := CIndexEtc(this)

  ** All defs by name (collisions removed)
  Str:CDef defsMap

  ** Return all subtypes
  CDef[] subtypes(CDef def)
  {
    if (!def.type.isTerm) return CDef#.emptyList

    return defs.findAll |x|
    {
      if (x.type.isKey) return false
      return x.supertypes.contains(def)
    }
  }

  ** Return set of markers to implement usage of this term
  CDef[]? implements(CDef def)
  {
    if (!def.isEntity) return null
    acc := Str:CDef[:] { ordered = true }
    def.inheritance.each |x|
    {
      if (x === def || x.has("mandatory"))
      {
        if (x.type.isConjunct)
          x.conjunct.tags.each |p| { acc[p.symbol.toStr] = p }
        else
          acc[x.symbol.toStr] = x
      }
    }
    return acc.vals
  }

  ** If def is an association return list of defs which use it as as tag
  CDef[] associationOn(CDef def)
  {
    if (!def.isAssociation) return CDef#.emptyList

    return defs.findAll |x|
    {
      x.declared[def.name] != null
    }
  }

//////////////////////////////////////////////////////////////////////////
// DefNamespace
//////////////////////////////////////////////////////////////////////////

  Bool hasProtos() { protosRef != null }
  CProto[] protos() { protosRef ?: throw Err("Protos not avail") }
  internal CProto[]? protosRef

  DefNamespace ns() { nsRef ?: throw Err("Namespace not avail") }
  internal DefNamespace? nsRef

  CDef[] nsMap(Def[] list)
  {
    if (list.isEmpty) return CDef#.emptyList
    return list.map |d->CDef| { def(d.symbol.toStr) }
  }

}

**************************************************************************
** CIndexEtc
**************************************************************************

class CIndexEtc
{
  new make(CIndex index) { this.index = index }

  once CDef association()  { index.def("association") }
  once CDef baseUri()      { index.def("baseUri") }
  once CDef choice()       { index.def("choice") }
  once CDef entity()       { index.def("entity") }
  once CDef enum()         { index.def("enum") }
  once CDef equip()        { index.def("equip") }
  once CDef feature()      { index.def("feature") }
  once CDef isDef()        { index.def("is") }
  once CDef lib()          { index.def("lib") }
  once CDef marker()       { index.def("marker") }
  once CDef quantity()     { index.def("quantity") }
  once CDef phenomenon()   { index.def("phenomenon") }
  once CDef point()        { index.def("point") }
  once CDef process()      { index.def("process") }
  once CDef relationship() { index.def("relationship") }
  once CDef ref()          { index.def("ref") }
  once CDef space()        { index.def("space") }
  once CDef tags()         { index.def("tags") }
  once CDef val()          { index.def("val") }
  once CDef version()      { index.def("version") }

  private CIndex index
}

