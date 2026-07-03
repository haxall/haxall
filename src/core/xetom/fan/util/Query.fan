//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using xeto

**
** Query
**
@Js
internal class Query
{

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, XetoContext cx, Dict opts)
  {
    this.ns = ns
    this.cx = cx
    this.opts = opts
    this.fitter = Fitter(ns, cx, opts)
  }

  Dict[] query(Dict subject, Spec query)
  {
    // verify its a query
    if (!query.isQuery)
    {
      throw ArgErr("Spec is not Query type: $query.qname")
    }

    // get of type
    of := query.of(false) ?: throw Err("No 'of' type specified: $query.qname")

    // via
    via := query["via"] as Str
    if (via != null) return queryVia(subject, of, query, via)

    // inverse
    inverse := query["inverse"] as Str
    if (inverse != null) return queryInverse(subject, of, query, inverse)

    throw Err("Query missing via or inverse meta: $query.qname")
  }

//////////////////////////////////////////////////////////////////////////
// Query Via
//////////////////////////////////////////////////////////////////////////

  private Dict[] queryVia(Dict subject, Spec of, Spec query, Str via)
  {
    multiHop := false
    if (via.endsWith("+"))
    {
      multiHop = true
      via = via[0..-2]
    }

    acc := Dict[,]
    traverseVia(subject, of, via, multiHop, Obj[,], acc)
    return acc
  }

  private Void traverseVia(Dict subject, Spec of, Str via, Bool multiHop, Obj[] visited, Dict[] acc)
  {
    toRefs(subject.get(via)).each |ref|
    {
      if (visited.contains(ref)) return // cyclic check
      visited.add(ref)
      rec := cx.xetoReadById(ref)
      if (rec == null) return
      if (fits(rec, of)) acc.add(rec) // can traverse over refs that don't match type
      if (multiHop) traverseVia(rec, of, via, multiHop, visited, acc)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Query Inverse
//////////////////////////////////////////////////////////////////////////

  private Dict[] queryInverse(Dict subject, Spec of, Spec query, Str inverseName)
  {
    inverse := ns.spec(inverseName, false)
    if (inverse == null) throw Err("Inverse of query '$query.qname' not found: $inverseName")

    // require inverse query to be structured as via (which is all we support anyways)
    via := inverse["via"] as Str
    if (via == null) throw Err("Inverse of query '$query.qname' must be via: '$inverse.qname'")
    multiHop := false
    if (via.endsWith("+"))
    {
      multiHop = true
      via = via[0..-2]
    }

    // read all via filter and find recs where via refs+ back to me
    subjectId := subject.trap("id", null)
    acc := Dict[,]
    cx.xetoReadAllEachWhile(via) |rec|
    {
       match := matchInverse(subjectId, rec, via, multiHop) && fits(rec, of)
       if (match) acc.add(rec)
       return null
    }
    return acc
  }

  private Bool matchInverse(Obj subjectId, Dict rec, Str via, Bool multiHop)
  {
    toRefs(rec[via]).any |ref->Bool|
    {
      if (ref == subjectId) return true

      if (!multiHop) return false

      x := cx.xetoReadById(ref)
      if (x == null) return false

      // TODO: need some cyclic checks
      return matchInverse(subjectId, x, via, multiHop)
    }
  }

  ** Via tag as list of refs; MultiRef values may be either Ref or Ref[]
  private static Obj[] toRefs(Obj? val)
  {
    if (val == null) return Obj#.emptyList
    return val as List ?: Obj[val]
  }

  private Bool fits(Obj? val, Spec spec)
  {
    fitter.valFits(val, spec)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const MNamespace ns
  private const Dict opts
  private XetoContext cx
  private Fitter fitter
}

