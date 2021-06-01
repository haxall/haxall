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
    config := cx.rt.config
    tags := Str:Obj?[:] { ordered = true }
    tags["haystackVersion"] = cx.ns.lib("ph").version.toStr
    tags["serverName"]      = Env.cur.host
    tags["serverBootTime"]  = DateTime.boot
    tags["serverTime"]      = DateTime.now
    tags["productName"]     = cx.rt.config["productName"]
    tags["productUri"]      = cx.rt.config["productUri"]
    tags["productVersion"]  = cx.rt.config["productVersion"]
    tags["tz"]              = TimeZone.cur.name
    tags["whoami"]          = cx.user.username
    tags["vendorName"]      = cx.rt.config["vendorName"]
    tags["vendorUri"]       = cx.rt.config["vendorUri"]
    return Etc.makeMapGrid(null, tags)
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



