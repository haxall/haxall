//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jun 2021  Brian Frank  Creation
//

using compilerDoc

**
** Theme overrides
**
const class DefDocTheme : DocTheme
{
  override Void writeStart(DocRenderer r)
  {
    DefDocEnv env := r.env
    out := (DocOutStream)r.out
    if (env.genFullHtml)
    {
      out.docType
      out.html
      out.head
        .w("<meta charset='UTF-8'/>")
        .title.w("$r.doc.title.toXml &ndash; $env.siteDis.toXml").titleEnd
        .includeCss(r.doc.isTopIndex ? `$env.cssFilename` : `../$env.cssFilename`)
        .headEnd
        .body("style='padding:0; background:#fff; margin:1em 4em 3em 6em;'")
    }

    out.div("class='defc'").nl
  }

  override Void writeBreadcrumb(DocRenderer r)
  {
    env := r.env
    doc := r.doc
    out := (DocOutStream)r.out
    nav := DocNavData()

    out.div("class='defc-nav'").ul
    writeBreadcrumbItem(r, env.topIndex, "Index", nav)
    if (!doc.isTopIndex)
    {
      writeBreadcrumbSep(r)
      writeBreadcrumbItem(r, doc.space.doc("index"), doc.space.breadcrumb, nav)
      if (!doc.isSpaceIndex)
      {
        if (doc is DocSrc)
        {
          src := (DocSrc)doc
          type := src.pod.type(src.uri.basename, false)
          if (type != null)
          {
            writeBreadcrumbSep(r)
            writeBreadcrumbItem(r, type, type.breadcrumb, nav)
          }
        }
        writeBreadcrumbSep(r)
        writeBreadcrumbItem(r, doc, doc.breadcrumb, nav)
      }
    }
    out.ulEnd.divEnd.hr.nl

    out.w("<!-- defc-breadcrumb").nl
    out.w(nav.encode)
    out.w("-->").nl
  }

  private Void writeBreadcrumbSep(DocRenderer r)
  {
    r.out.li.w(" \u00BB ").liEnd
  }

  private Void writeBreadcrumbItem(DocRenderer r, Doc doc, Str dis, DocNavData nav)
  {
    uri := r.env.linkUri(DocLink(r.doc, doc, dis))
    r.out.li.a(uri).esc(dis).aEnd.liEnd
    nav.add(uri, dis, 0)
  }

  override Void writeEnd(DocRenderer r)
  {
    env := (DefDocEnv)r.env
    out := (DocOutStream)r.out
    out.defSection("")
       .p("class='defc-footer-ts'").esc(env.footer).pEnd
       .defSectionEnd
       .divEnd

    if (env.genFullHtml)
    {
      out.bodyEnd.htmlEnd
    }
  }

}

