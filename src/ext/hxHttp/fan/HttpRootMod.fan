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
  new make(HttpExt ext) { this.rt = ext.rt; this.ext = ext }

  const HxRuntime rt
  const HttpExt ext

  override Void onService()
  {
    req := this.req
    res := this.res

    // use first level of my path to lookup lib
    libName := req.modRel.path.first ?: ""

    // if name is empty, redirect
    if (libName.isEmpty)
    {
      // redirect to shell as the built-in UI
      return res.redirect(`/shell`)
    }

    // lookup lib as hxFoo and foo
    lib := rt.libsOld.get("hx"+libName.capitalize, false)
    if (lib == null) lib = rt.libsOld.get(libName, false)
    if (lib == null) return res.sendErr(404)

    // check if it supports ExtWeb
    libWeb := lib.web
    if (libWeb.isUnsupported) return res.sendErr(404)

    // dispatch to lib's ExtWeb instance
    req.mod = libWeb
    req.modBase = req.modBase + `$libName/`
    libWeb.onService
  }
}

