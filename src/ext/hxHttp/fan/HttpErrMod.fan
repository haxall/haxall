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
** Error handling web module
**
internal const class HttpErrMod : WebMod
{
  new make(HttpExt ext) { this.ext = ext }

  const HttpExt ext

  override Void onService()
  {
    err := (Err)req.stash["err"]
    errTrace := ext.settings.disableErrTrace ? err.toStr : err.traceToStr

    res.headers["Content-Type"] = "text/html; charset=utf-8"
    res.out.html
     .head
       .title.w("$res.statusCode INTERNAL SERVER ERROR").titleEnd
     .headEnd
     .body
       .h1.w("$res.statusCode INTERNAL SERVER ERROR").h1End
       .pre.esc(errTrace).preEnd
     .bodyEnd
     .htmlEnd
  }
}

