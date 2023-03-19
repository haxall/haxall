//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using data

**
** Query
**
@Js
class Query
{

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  new make(DataEnv env, DataContext cx, DataDict opts)
  {
    this.env = env
    this.cx = cx
    this.opts = opts
    this.fitter = Fitter(env, cx, opts)
  }

  DataDict[] query(DataDict subject, DataSpec query)
  {
    // verify its a query
    if (!query.isQuery)
    {
if (query.base.isQuery) echo("TODO: fix inheritance: $query")
else
      throw ArgErr("Spec is not Query type: $query.qname")
    }

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

  private DataDict[] queryVia(DataDict subject, DataSpec of, DataSpec query, Str via)
  {
    multiHop := false
    if (via.endsWith("+"))
    {
      multiHop = true
      via = via[0..-2]
    }

    acc := DataDict[,]
    cur := subject as DataDict
    while (true)
    {
      cur = matchVia(cur, of, via)
      if (cur == null) break
      acc.add(cur)
      if (!multiHop) break
    }
    return acc
  }

  private DataDict? matchVia(DataDict subject, DataSpec of, Str via)
  {
    ref := subject.get(via, null)
    if (ref == null) return null

    rec := cx.dataReadById(ref)
    if (rec == null) return rec

    if (!fits(rec, of)) return null

    return rec
  }

//////////////////////////////////////////////////////////////////////////
// Query Inverse
//////////////////////////////////////////////////////////////////////////

  private DataDict[] queryInverse(DataDict subject, DataType of, DataSpec query, Str inverseName)
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

    // read all via filter and find recs where via refs+ back to me
    subjectId := subject.trap("id", null)
    acc := DataDict[,]
    cx.dataReadAllEachWhile(via) |rec|
    {
       match := matchInverse(subjectId, rec, via, multiHop) && fits(rec, of)
       if (match) acc.add(rec)
       return null
    }
    return acc
  }

  private Bool matchInverse(Obj subjectId, DataDict rec, Str via, Bool multiHop)
  {
    ref := rec[via]
    if (ref == null) return false

    if (ref == subjectId) return true

    if (!multiHop) return false

    x := cx.dataReadById(ref)
    if (x == null) return false

    // TODO: need some cyclic checks
    return matchInverse(subjectId, x, via, multiHop)
  }

  private Bool fits(Obj? val, DataSpec spec)
  {
    fitter.valFits(val, spec)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const DataEnv env
  private const DataDict opts
  private DataContext cx
  private Fitter fitter
}


