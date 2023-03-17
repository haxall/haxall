//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using data
using haystack
using hx

**
** Query
**
class Query
{

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  new make(HxContext cx)
  {
    this.cx = cx
    this.env = cx.usings.data
  }

  Dict[] query(Dict subject, DataSpec query)
  {
    // verify its a query
    if (!query.isQuery) throw ArgErr("Spec is not Query type: $query.qname")

    // get of type
    of := query["of"] as DataSpec ?: throw Err("No 'of' type specified: $query.qname")

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

  private Dict[] queryVia(Dict subject, DataSpec of, DataSpec query, Str via)
  {
    multiHop := false
    if (via.endsWith("+"))
    {
      multiHop = true
      via = via[0..-2]
    }

    acc := Dict[,]
    cur := subject as Dict
    while (true)
    {
      cur = matchVia(cur, of, via)
      if (cur == null) break
      acc.add(cur)
      if (!multiHop) break
    }
    return acc
  }

  private Dict? matchVia(Dict subject, DataSpec of, Str via)
  {
    ref := subject.get(via, null) as Ref
    if (ref == null) return null

    rec := cx.deref(ref)
    if (rec == null) return rec

    if (!env.fits(rec, of, null)) return null

    return rec
  }

//////////////////////////////////////////////////////////////////////////
// Query Inverse
//////////////////////////////////////////////////////////////////////////

  private Dict[] queryInverse(Dict subject, DataType of, DataSpec query, Str inverseName)
  {
    inverse := env.spec(inverseName, false)
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

    // read all via filter
    potentialRecs := cx.db.readAllList(Filter.has(via))

    // find all potentials that have via refs+ back to me
    subjectId := subject.id
    return potentialRecs.findAll |rec|
    {
      matchInverse(subjectId, rec, via, multiHop) && env.fits(rec, of, null)
    }
  }

  private Bool matchInverse(Ref subjectId, Dict rec, Str via, Bool multiHop)
  {
    ref := rec[via] as Ref
    if (ref == null) return false

    if (ref == subjectId) return true

    if (!multiHop) return false

    x := cx.deref(ref)
    if (x == null) return false

    // TODO: need some cyclic checks
    return matchInverse(subjectId, x, via, multiHop)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private HxContext cx
  private DataEnv env
}


