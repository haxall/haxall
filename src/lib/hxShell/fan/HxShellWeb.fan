//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jun 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using hx

**
** Web handling
**
const class HxShellWeb : HxLibWeb
{
  new make(HxShellLib lib) : super(lib)
  {
    this.lib   = lib
    this.title = "" + rt.platform.productName + " Shell"
  }

  override const HxShellLib lib

  const Str title

  override Void onService()
  {
    cx := rt.user.authenticate(req, res)
    if (cx == null) return

    if (!cx.user.isAdmin) return res.sendErr(403)

    route := req.modRel.path.getSafe(0)
    switch (route)
    {
      case null:        return onHtml(cx)
      case "shell.css": return onCss
      case "shell.js":  return onJs
      default:          return res.sendErr(404)
    }
  }

  private Void onHtml(HxContext cx)
  {
    if (req.method != "GET") { res.sendErr(501); return }

    env := Str:Str[:]
    env["main"]              = "hxShell::Shell.main"
    env["hxShell.api"]       = cx.rt.http.apiUri.toStr
    env["hxShell.attestKey"] = cx.session.attestKey
    env["hxShell.user"]      = ZincWriter.valToStr(cx.user.meta)

    res.headers["Content-Type"] = "text/html; charset=utf-8"
    out := res.out
    out.docType5
     .html
     .head
     .title.w(title).titleEnd
     .tag("meta", "charset='UTF-8'", true).nl
     .tag("meta", "name='google' content='notranslate'", true).nl
     .includeCss(this.uri+`shell.css`)
     .initJs(env)
     .includeJs(this.uri+`shell.js`)

    out.headEnd
    out.body.bodyEnd
    out.htmlEnd
  }

  private Void onCss()
  {
    pack := FilePack(FilePack.toAppCssFiles(pods))
    //lib.log.info("shell.css [" + pack.buf.size.toLocale("B") + "]")
    pack.onService
  }

  private Void onJs()
  {
    pack := FilePack(FilePack.toAppJsFiles(pods))
    //lib.log.info("shell.js [" + pack.buf.size.toLocale("B") + "]")
    pack.onService
  }

  private Pod[] pods() { [typeof.pod] }
}