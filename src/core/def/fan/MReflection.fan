//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Dec 2018  Brian Frank  Creation
//

using concurrent
using haystack

**
** Reflection implementation
**
@NoDoc @Js
internal const class MReflection : Reflection
{

//////////////////////////////////////////////////////////////////////////
// Factory
//////////////////////////////////////////////////////////////////////////

  static MReflection reflect(MNamespace ns, Dict subject)
  {
    // conjuncts
    defs := Def[,]
    ns.lazy.conjuncts.each |def|
    {
      if (matchConjunct(subject, def)) defs.add(def)
    }

    // single tags
    subject.each |v, n|
    {
      if (v == null) return
      def := ns.def(n, false)
      if (def != null) defs.add(def)
    }

    // return implementation
    return MReflection(ns, subject, defs)
  }

  private static Bool matchConjunct(Dict subject, Def conjunct)
  {
    // return if any part doesn't match
    symbol := conjunct.symbol
    for (i := 0; i<symbol.size; ++i)
      if (subject.missing(symbol.part(i))) return false
    return true
  }

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  private new make(MNamespace ns, Dict subject, Def[] defs)
  {
    this.ns      = ns
    this.subject = subject
    this.defs    = defs.sort
  }

//////////////////////////////////////////////////////////////////////////
// Reflection
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns

  override const Dict subject

  override const Def[] defs

  override Def? def(Str symbol, Bool checked := true)
  {
    def := defs.find |x| { x.symbol.toStr == symbol }
    if (def != null) return def
    if (checked) throw UnknownDefErr(symbol)
    return null
  }

  override Bool fits(Def base)
  {
    defs.any |x| { ns.fits(x, base) }
  }

  override Def[] entityTypes()
  {
    x := entityTypesRef.val
    if (x == null) entityTypesRef.val = x = computeEntityTypes.toImmutable
    return x
  }
  private const AtomicRef entityTypesRef := AtomicRef()

  private Def[] computeEntityTypes()
  {
    // find only entity types
    acc := defs.findAll |def| { ns.fitsEntity(def) }

    // if zero or one found, then we are done
    if (acc.size <= 1) return acc

    // strip any defs which is a supertype of one of the others
    acc = acc.exclude |a|
    {
      acc.any |b| { a !== b && ns.fits(b, a) }
    }

    return acc
  }

  override Grid toGrid()
  {
    Etc.makeDictsGrid(null, defs)
  }
}