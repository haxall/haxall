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
    pageStart(p)
    pageHeader(p)
    switch (p.pageType)
    {
      case DocPageType.spec:     spec(p)
      case DocPageType.instance: instance(p)
      case DocPageType.lib:      lib(p)
      case DocPageType.chapter:  chapter(p)
      default:                   throw Err(p.pageType.toStr)
    }
    pageEnd
    return this
  }

  private Void lib(DocLib p)
  {
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

    // <xetodoc-page> <xetodoc-main>
    tag(tagPage).nl
    tag(tagMain).nl
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

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const Str tagPage    := "xetodoc-page"
  static const Str tagMain    := "xetodoc-main" // two column tab+section
  static const Str tagTab     := "xetodoc-tab"
  static const Str tagSection := "xetodoc-section"
  static const Str tagFooter  := "xetodoc-footer"

  Bool fullHtml := true
  Str footerText := "footer"
  Str cssFilename := "xetodoc.css"
}

