//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Jan 2010  Brian Frank  Creation
//   05 Jan 2016  Brian Frank  Refactor for 3.0
//

using xeto
using haystack

**
** ReadCache manages all the reads to a given database and
** caches the result so that further reads don't need to go
** back to database.
**
@NoDoc class ReadCache
{
  new make(Folio folio) { this.folio = folio }

  const Folio folio

  Dict? readById(Ref id, Bool checked := true)
  {
    r := byId[id]
    if (r == null)
    {
      ++misses
      r = folio.readById(id, false) ?: notFound
      byId[id] = r
    }
    if (r !== notFound) return r
    if (checked) throw UnknownRecErr(id.toStr)
    return null
  }

  Dict?[] readByIdsList(Ref[] ids, Bool checked := true)
  {
    ids.map |id->Dict?| { readById(id, checked) }
  }

  Grid readByIds(Ref[] ids, Bool checked := true)
  {
    g := folio.readByIds(ids, checked)
    g.each { add(it) }
    return g
  }

  Dict? read(Str filter, Bool checked := true)
  {
    r := folio.read(Filter(filter), checked)
    if (r != null) add(r)
    return r
  }

  Grid readAll(Str filter)
  {
    r := folio.readAll(Filter(filter))
    r.each { add(it) }
    return r
  }

  Int readCount(Str filter)
  {
    folio.readCount(Filter(filter))
  }

  @NoDoc Void add(Dict? rec)
  {
    if (rec == null) return
    i := rec["id"] as Ref; if (i != null) byId[i] = rec
  }

  @NoDoc Void addAll(Dict?[] recs)
  {
    recs.each |rec| { add(rec) }
  }

  private const static Dict notFound := Etc.makeDict(["notFound":Marker.val])

  private Ref:Dict byId := [:]
  internal Int misses  // for testing
}

