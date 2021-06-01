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


