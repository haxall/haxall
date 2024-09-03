//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Dec 2018  Brian Frank  Creation
//

using concurrent
using haystack

**
** MLazy is used to manage lazily data structures a per overlay basis.
**
@NoDoc @Js
const class MLazy
{
  new make(MNamespace ns) { this.ns = ns }

//////////////////////////////////////////////////////////////////////////
// Conjuncts
//////////////////////////////////////////////////////////////////////////

  ** List of all conjuncts sorted by most parts to least parts
  Def[] conjuncts()
  {
    x := conjunctsRef.val
    if (x == null) conjunctsRef.val = x = initConjuncts
    return x
  }

  private Def[] initConjuncts()
  {
    acc := ns.findDefs |def| { def.symbol.type.isConjunct }
    acc.sortr |a, b| { a.symbol.size <=> b.symbol.size }
    return acc.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Has Subtypes
//////////////////////////////////////////////////////////////////////////

  Bool hasSubtypes(Def def)
  {
    key := def.symbol.toStr
    r := hasSubtypesCache[key]
    if (r == null) hasSubtypesCache[key] = r = doHasSubtypes(def)
    return r
  }

  private Bool doHasSubtypes(Def def)
  {
    ns.hasDefs |x| { ns.matchSubtype(def, x) }
  }

//////////////////////////////////////////////////////////////////////////
// Associations
//////////////////////////////////////////////////////////////////////////

  Def[] associations(Def parent, Def assoc)
  {
    key := "$parent.symbol|$assoc.symbol"
    r := associationsCache[key]
    if (r == null) associationsCache[key] = r = doAssociations(parent, assoc)
    return r
  }

  private Def[] doAssociations(Def parent, Def assoc)
  {
    // if declared association then is just a tag on the parent
    if (assoc.missing("computedFromReciprocal"))
      return DefUtil.resolveList(ns, parent[assoc.name]).toImmutable

    // computed requires the reciprocalOf
    reciprocalOf := assoc.get("reciprocalOf") as Symbol
    if (reciprocalOf == null) throw ArgErr("Computed association missing reciprocalOf")
    r := ns.def(reciprocalOf.toStr)

    // find all defs with matching reciprocal
    matches := ns.findDefs |d|
    {
      rv := ns.declared(d, r.name)
      if (rv == null) return false
      return DefUtil.resolveList(ns, rv).any |x| { ns.fits(parent, x) }
    }
    if (matches.isEmpty) return Def#.emptyList
    return matches.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// ContainedByRefs
//////////////////////////////////////////////////////////////////////////

  ** All the ref tags which implemented containedBy association
  Def[] containedByRefs()
  {
    x := containedByRefsRef.val
    if (x == null) containedByRefsRef.val = x = initContainedByRefs
    return x
  }

  private Def[] initContainedByRefs()
  {
    acc := ns.findDefs |def| { def.has("containedBy") && ns.fits(def, ns.quick.ref) }
    acc.sort |a, b| { a.symbol.toStr <=> b.symbol.toStr }
    return acc.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns
  private const AtomicRef conjunctsRef := AtomicRef()
  private const AtomicRef containedByRefsRef := AtomicRef()
  private const ConcurrentMap hasSubtypesCache := ConcurrentMap()  // Symbol.toStr -> Bool
  private const ConcurrentMap associationsCache := ConcurrentMap()  // "parent|assoc" -> Def[]
  private const ConcurrentMap choicesCache := ConcurrentMap()  // Symbol.toStr -> Def[]
}

