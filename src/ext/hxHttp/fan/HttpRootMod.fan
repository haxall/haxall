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
    // route to ext
    ext.onService(req, res)
  }
}

