//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Dec 2015  Brian Frank  Creation
//   22 Sep 2021  Brian Frank  Port to Haxall
//

using concurrent
using inet
using web
using wisp
using haystack
using hx

**
** Root handling web module
**
internal const class HttpRootMod : WebMod
{
  new make(HttpExt ext)
  {
    this.sys = ext.sys
    this.ext = ext
  }

  const Sys sys
  const HttpExt ext

  override Void onService()
  {
    req := this.req
    res := this.res

    // use first level of my path to lookup route
    routeName := req.modRel.path.first ?: ""

    // if name is empty then authenticate and perform index redirect
    if (routeName.isEmpty)
    {
      // index redirect
      session := sys.user.authenticate(req, res)
      if (session == null) return
      cx := sys.newContextSession(session)
      uri := ext.indexRedirectUri(cx)
      return res.redirect(uri)
    }

    // get the webmod for given route
    mod := sys.exts.webRoutes.get(routeName)
    if (mod == null) return res.sendErr(404)

    // dispatch to web mod
    req.mod = mod
    req.modBase = req.modBase + `$routeName/`
    mod.onService
  }
}

