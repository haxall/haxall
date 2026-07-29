//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon
using folio
using hx

**
** Haxall "hx.api" axon functions which define the HTTP API operations
** specific to Haxall
**
@Gen
const class ApiFuncs
{

  ** Add, update, or remove entities in the database.  The grid meta
  ** `commit` tag selects the mode:
  **   - "add": each row is a new entity; the `id` column is optional and
  **     is generated when omitted
  **   - "update": each row must have `id` and `mod` columns, where `mod`
  **     is the entity's current modified timestamp used for optimistic
  **     concurrency.  Grid meta may specify the `force` marker to skip
  **     the concurrency check, and `transient` to avoid persisting.
  **   - "remove": each row must have `id` and `mod` columns; grid meta
  **     may specify the `force` marker
  **
  ** Returns a grid of the resulting entities for add and update, or an
  ** empty grid for remove.  Requires admin permission.
  **
  ** Also see `hx::Funcs.commit` which takes a list of diffs, and
  ** [hx.doc.skyspark::Ops#commit] for the HTTP API details.
  @Api @Axon { admin = true }
  static Grid commit(Grid req)
  {
    cx := curContext
    if (!cx.user.isAdmin) throw PermissionErr("Missing 'admin' permission: commit")
    mode := req.meta->commit
    switch (mode)
    {
      case "add":    return commitAdd(req, cx)
      case "update": return commitUpdate(req, cx)
      case "remove": return commitRemove(req, cx)
      default:       throw ArgErr("Unknown commit mode: $mode")
    }
  }

  private static Grid commitAdd(Grid req, Context cx)
  {
    diffs := Diff[,]
    req.each |row|
    {
      changes := Str:Obj?[:]
      Ref? id := null
      row.each |v, n|
      {
        if (n == "id") { id = v; return }
        changes.add(n, v)
      }
      diffs.add(Diff.makeAdd(changes, id ?: Ref.gen))
    }
    newRecs := cx.db.commitAll(diffs).map |d->Dict| { d.newRec }
    return Etc.makeDictsGrid(null, newRecs)
  }

  private static Grid commitUpdate(Grid req, Context cx)
  {
    flags := 0
    if (req.meta.has("force"))     flags = flags.or(Diff.force)
    if (req.meta.has("transient")) flags = flags.or(Diff.transient)

    diffs := Diff[,]
    req.each |row|
    {
      old := Etc.makeDict(["id":row.id, "mod":row->mod])
      changes := Str:Obj?[:]
      row.each |v, n|
      {
        if (n == "id" || n == "mod") return
        changes.add(n, v)
      }
      diffs.add(Diff(old, changes, flags))
    }
    newRecs := cx.db.commitAll(diffs).map |d->Dict| { d.newRec }
    return Etc.makeDictsGrid(null, newRecs)
  }

  private static Grid commitRemove(Grid req, Context cx)
  {
    flags := Diff.remove
    if (req.meta.has("force")) flags = flags.or(Diff.force)

    diffs := Diff[,]
    req.each |row| { diffs.add(Diff(row, null, flags)) }
    cx.db.commitAll(diffs)
    return Etc.makeEmptyGrid
  }

  ** Evaluate an expression and return the result as a grid.  The request
  ** grid has a single row with an `expr` column.  If the expression parses
  ** as a [filter](ph.doc::Filters) such as "site and area > 1000" then it
  ** is read as a query, otherwise it is evaluated as an Axon expression.
  **
  ** Also see `axon::Funcs.eval` which evaluates an expression directly without
  ** the filter convenience, and [hx.doc.skyspark::Ops#eval] for the HTTP
  ** API details.
  @Api @Axon
  static Grid eval(Grid req)
  {
    if (req.isEmpty) throw Err("Request grid is empty")
    expr := (Str)req.first->expr
    return Etc.toGrid(curContext.evalOrReadAll(expr))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Current context
  private static Context curContext() { Context.cur }
}
