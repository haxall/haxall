//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jun 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using folio
using hx

**
** Base class for HTTP API operation processing
**
abstract class HxApiOp
{
  virtual Void onService(WebReq req, WebRes res, HxContext cx)
  {
    // parse request grid; if readReq returns null
    // then an error has already been returned
    reqGrid := readReq(req, res)
    if (reqGrid == null) return

     // subclass hook
     resGrid := onRequest(reqGrid, cx)

     // respond with resulting grid
     writeRes(req, res, resGrid)
   }

  ** Process request
  abstract Grid onRequest(Grid req, HxContext cx)

  ** Read Haystack op request grid or null on error
  Grid? readReq(WebReq req, WebRes res)
  {
    support.doReadReq(req, res)
  }

  ** Write Haystack op response grid
  Void writeRes(WebReq req, WebRes res, Obj? result)
  {
    if (res.isCommitted) return
    support.doWriteRes(req, res, Etc.toGrid(result))
  }

  internal HxApiWeb? support  // set by HxApiWeb.onService
}

**************************************************************************
** HxAboutOp
**************************************************************************

internal class HxAboutOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    Etc.makeDictGrid(null, cx.rt.core.funcs.about)
  }
}

**************************************************************************
** HxDefsOp
**************************************************************************

internal class HxDefsOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    opts := req.first as Dict ?: Etc.emptyDict
    limit := (opts["limit"] as Number)?.toInt ?: Int.maxVal
    filter := Filter.fromStr(opts["filter"] as Str ?: "", false)
    acc := Def[,]
    incomplete := false
    eachDef(cx) |def|
    {
      if (filter != null && !filter.matches(def, cx)) return
      if (acc.size >= limit) { incomplete = true; return }
      acc.add(def)
    }
    meta := incomplete ? Etc.makeDict2("incomplete", Marker.val, "limit", Number(limit)) : Etc.emptyDict
    return Etc.makeDictsGrid(meta, acc)
  }

  virtual Void eachDef(HxContext cx, |Def| f) { cx.ns.eachDef(f) }
}

**************************************************************************
** HxFiletypesOp
**************************************************************************

internal class HxFiletypesOp : HxDefsOp
{
  override Void eachDef(HxContext cx, |Def| f) { cx.ns.filetypes.each(f) }
}

**************************************************************************
** HxLibsOp
**************************************************************************

internal class HxLibsOp : HxDefsOp
{
  override Void eachDef(HxContext cx, |Def| f) { cx.ns.libsList.each(f) }
}

**************************************************************************
** HxOpsOp
**************************************************************************

internal class HxOpsOp : HxDefsOp
{
  override Void eachDef(HxContext cx, |Def| f) { cx.ns.feature("op").eachDef(f) }
}

**************************************************************************
** HxReadOp
**************************************************************************

internal class HxReadOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    if (req.isEmpty) throw Err("Request grid is empty")

    if (req.has("filter"))
    {
      reqRow := req.first
      filter := (Str)reqRow->filter
      opts   := reqRow
      return cx.db.readAll(filter, opts)
    }

    if (req.has("id"))
    {
      return cx.db.readByIds(req.ids, false)
    }

    throw Err("Request grid missing id or filter col")
  }
}

**************************************************************************
** HxEvalOp
**************************************************************************

internal class HxEvalOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    if (req.isEmpty) throw Err("Request grid is empty")
    expr := (Str)req.first->expr
    return Etc.toGrid(cx.evalOrReadAll(expr))
  }
}

**************************************************************************
** HxCommitOp
**************************************************************************

internal class HxCommitOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    if (!cx.user.isAdmin) throw PermissionErr("Missing 'admin' permission: commit")
    mode := req.meta->commit
    switch (mode)
    {
      case "add":    return onAdd(req, cx)
      case "update": return onUpdate(req, cx)
      case "remove": return onRemove(req, cx)
      default:       throw ArgErr("Unknown commit mode: $mode")
    }
  }

  private Grid onAdd(Grid req, HxContext cx)
  {
    diffs := Diff[,]
    req.each |row|
    {
      changes := Str:Obj?[:]
      Ref? id := null
      row.each |v, n|
      {
        if (v == null) return
        if (n == "id") { id = v; return }
        changes.add(n, v)
      }
      diffs.add(Diff.makeAdd(changes, id ?: Ref.gen))
    }
    newRecs := cx.db.commitAll(diffs).map |d->Dict| { d.newRec }
    return Etc.makeDictsGrid(null, newRecs)
  }

  private Grid onUpdate(Grid req, HxContext cx)
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
        if (v == null) return
        if (n == "id" || n == "mod") return
        changes.add(n, v)
      }
      diffs.add(Diff(old, changes, flags))
    }
    newRecs := cx.db.commitAll(diffs).map |d->Dict| { d.newRec }
    return Etc.makeDictsGrid(null, newRecs)
  }

  private Grid onRemove(Grid req, HxContext cx)
  {
    flags := Diff.remove
    if (req.meta.has("force")) flags = flags.or(Diff.force)

    diffs := Diff[,]
    req.each |row| { diffs.add(Diff(row, null, flags)) }
    cx.db.commitAll(diffs)
    return Etc.makeEmptyGrid
  }
}

