//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Dec 2025  Brian Frank  Creation
//

using xeto
using haystack
using web

**
** DocHtmlWriter renders DocPages to HTML
**
class DocHtmlWriter : WebOutStream
{
  new make(OutStream out) : super(out) {}

//////////////////////////////////////////////////////////////////////////
// Pages
//////////////////////////////////////////////////////////////////////////

  This page(DocPage p)
  {
    curPage = p
    pageStart(p)
    pageHeader(p)
    switch (p.pageType)
    {
      case DocPageType.spec:     spec(p)
      case DocPageType.instance: instance(p)
      case DocPageType.chapter:  chapter(p)
      case DocPageType.lib:      lib(p)
      case DocPageType.index:    index(p)
      default:                   throw Err(p.pageType.toStr)
    }
    pageEnd
    curPage = null
    return this
  }

  private Void index(DocIndex p)
  {
  }

  private Void lib(DocLib p)
  {
    summarySection("chapters",  p.chapters)
    summarySection("mixins",    p.mixins)
    summarySection("types",     p.types)
    summarySection("instances", p.instances)
  }

  private Void spec(DocSpec p)
  {
  }

  private Void instance(DocInstance p)
  {
  }

  private Void chapter(DocChapter p)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Page Chrome
//////////////////////////////////////////////////////////////////////////

  private Void pageStart(DocPage p)
  {
    if (fullHtml)
    {
      docType
      html
      head
       .w("<meta charset='UTF-8'/>").nl
       .title.esc(p.title).titleEnd
       .includeCss(p.uri.path.size == 1 ? `$cssFilename` : `../$cssFilename`)
       .headEnd
       .body("style='padding:0; background:#fff; margin:1em 4em 3em 6em;'")
    }

    // <xetodoc-page>
    tag(tagPage).nl.nl

    // <xetodoc-nav>
    pageNav(p).nl.nl

    // <xetodoc-main>
    tag(tagMain).nl
  }

  private This pageNav(DocPage p)
  {
    nav := p.nav
    tag(tagNav).nl
    ul
    p.nav.each |link, i|
    {
      // separator
      if (i > 0) li.w(" \u00BB ").liEnd

      // link item
      li.link(link).liEnd.nl
    }
    ulEnd
    tagEnd(tagNav)
    return this
  }

  private Void pageHeader(DocPage p)
  {
    tabSection(p.pageType.name)
    h1.esc(p.title).h1End
    tabSectionEnd
  }

  private Void pageEnd()
  {
    // footer
    tabSection("")
    tag(tagFooter).esc(footerText).tagEnd(tagFooter)
    tabSectionEnd

    // </xetodoc-main> </xetodoc-page>
    tagEnd(tagMain).nl
    tagEnd(tagPage).nl

    // </body> </html>
    if (fullHtml) bodyEnd.htmlEnd
  }

//////////////////////////////////////////////////////////////////////////
// Sections
//////////////////////////////////////////////////////////////////////////

  private This tabSection(Str title, Str id := title)
  {
    nl
    tag(tagTab, "id='$id.toXml'").esc(title).tagEnd(tagTab).nl
    tag(tagSection).nl
    return this
  }

  private This tabSectionEnd()
  {
    nl.tagEnd(tagSection).nl.nl
  }

  private This summarySection(Str title, DocSummary[] summaries)
  {
    if (summaries.isEmpty) return this

    tabSection(title)
    props
    summaries.each |s| { prop(s.link, s.text) }
    propsEnd
    tabSectionEnd

    return this
  }

//////////////////////////////////////////////////////////////////////////
// Props
//////////////////////////////////////////////////////////////////////////

  private This props() { tag(tagProps).nl }

  private This propsEnd() { tagEnd(tagProps) }

  private This prop(Obj name, Obj? val)
  {
    if (val == null) return this
    tag(tagProp)
      .tag(tagPropTh).propName(name).tagEnd(tagPropTh)
      .tag(tagPropTd).propVal(val).tagEnd(tagPropTd)
      .tagEnd(tagProp).nl
    return this
  }

  private This propName(Obj name)
  {
    if (name is DocLink)
    {
      link(name)
    }
    else
    {
      esc(name)
    }
    return this
  }

  private This propVal(Obj? val)
  {
    if (val is Uri)         return uriVal(val)
    if (val is List)        return listVal(val)
    if (val is Dict)        return dictVal(val)
    if (val is DocMarkdown) return markdown(val)
    return esc(Etc.valToDis(val))
  }

  private This listVal(List val)
  {
    val.each |v, i| { if (i > 0) w(", "); propVal(v) }
    return this
  }

  private This dictVal(Dict val)
  {
    w("{")
    i := 0
    val.each |v, n|
    {
      if (i > 0) w(", ")
      w(n)
      if (v != Marker.val) { w(":"); propVal(v) }
      i++
    }
    return w("}")
  }

  private This uriVal(Uri uri)
  {
    uri.isAbs ? a(uri).esc(uri).aEnd : esc(uri.toStr)
  }

  private This propTitle(Str title)
  {
    tr.th("class='xetodoc-prop-title' colspan='2'").esc(title).thEnd.trEnd
  }

  private This indent(Int indentation)
  {
    indentation.times { w("&nbsp;&nbsp;&nbsp;&nbsp;") }
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Markdown
//////////////////////////////////////////////////////////////////////////

  private This markdown(DocMarkdown md)
  {
    esc(md.text)
  }

//////////////////////////////////////////////////////////////////////////
// Links
//////////////////////////////////////////////////////////////////////////

  private This link(DocLink link)
  {
    a(href(link.uri, ".html")).esc(link.dis).aEnd
  }

  private Uri href(Uri uri, Str? ext := null)
  {
    if (curPage == null) throw Err("No current page")
    cur := curPage.uri
    s := StrBuf()
    if (cur.path.first != uri.path.first)
    {
      s.add("../")
      if (uri.path.size > 1) s.add(uri.path[1]).addChar('/')
    }
    s.add(uri.name).joinNotNull(ext, "")
    return s.toStr.toUri
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const Str tagPage    := "xetodoc-page"
  static const Str tagNav     := "xetodoc-nav"
  static const Str tagMain    := "xetodoc-main" // two column tab+section
  static const Str tagTab     := "xetodoc-tab"
  static const Str tagSection := "xetodoc-section"
  static const Str tagProps   := "xetodoc-prop-table"
  static const Str tagProp    := "xetodoc-prop-tr"
  static const Str tagPropTh  := "xetodoc-prop-th"
  static const Str tagPropTd  := "xetodoc-prop-td"
  static const Str tagFooter  := "xetodoc-footer"

  Bool fullHtml := true
  Str footerText := "footer"
  Str cssFilename := "xetodoc.css"
  private DocPage? curPage
}

