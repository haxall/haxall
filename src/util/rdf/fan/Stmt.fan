//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Jan 2019  Matthew Giannini  Creation
//

**
** Models an RDF statment.
**
// TODO: Support for blank nodes in the subject
@Js const class Stmt
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Iri subject, Iri predicate, Obj object)
  {
    this.subj = subject
    this.pred = predicate
    this.obj  = object
    this.hash = hashCombine(hashCombine(hashObj(subj), hashObj(pred)), hashObj(obj))
  }

  private static Int hashObj(Obj? x) { x?.hash ?: 23 }
  private static Int hashCombine(Int h1, Int h2)
  {
    // ((h1 << 5) + h1) ^ h2)
    (h1.shiftl(5) + h1).xor(h2)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** The subject of the statement
  const Iri subj

  ** The predicate of the statement
  const Iri pred

  ** The object of the statement
  const Obj obj

//////////////////////////////////////////////////////////////////////////
// Normalize
//////////////////////////////////////////////////////////////////////////

  ** Get a new statement where all IRIs that have a prefix in the 'prefixMap'
  ** are fully expanded.
  Stmt normalize([Str:Str] prefixMap)
  {
    Stmt(subj.fullIri(prefixMap),
         pred.fullIri(prefixMap),
         (obj as Iri)?.fullIri(prefixMap) ?: obj)
  }

  ** Get a new statement where all IRIs are prefixed based on the given 'prefixMap'
  Stmt prefix([Str:Str] prefixMap)
  {
    Stmt(subj.prefixIri(prefixMap),
         pred.prefixIri(prefixMap),
         (obj as Iri)?.prefixIri(prefixMap) ?: obj)
  }

//////////////////////////////////////////////////////////////////////////
// Obj
//////////////////////////////////////////////////////////////////////////

  override Int compare(Obj obj)
  {
    that := obj as Stmt
    if (that == null) return super.compare(that)
    cmp := this.subj <=> that.subj
    if (cmp != 0) return cmp
    cmp = this.pred <=> that.pred
    if (cmp != 0) return cmp
    return this.obj <=> that.obj
  }

  const override Int hash

  override Bool equals(Obj? obj)
  {
    if (this === obj) return true
    that := obj as Stmt
    if (that == null) return false
    if (this.subj != that.subj) return false
    if (this.pred != that.pred) return false
    if (this.obj != that.obj) return false
    return true
  }

  override Str toStr() { "(${subj}, ${pred}, ${obj})" }
}