//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Dec 2025  Brian Frank  Creation
//

using xeto
using xetom
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
    switch (p.pageType)
    {
      case DocPageType.spec:     spec(p)
      case DocPageType.instance: instance(p)
      case DocPageType.chapter:  chapter(p)
      case DocPageType.lib:      lib(p)
      case DocPageType.index:    index(p)
      case DocPageType.search:   search(p)
      default:                   throw Err(p.pageType.toStr)
    }
    pageEnd(p)
    curPage = null
    return this
  }

  private Void index(DocIndex p)
  {
    pageHeader(p, "index")
    p.groups.each |g| { summarySection(g.title, g.links) }
  }

  private Void lib(DocLib p)
  {
    pageHeader(p, "lib")
    dictSection("meta", p.meta)
    summarySection("chapters",  p.chapters)
    summarySection("mixins",    p.mixins)
    summarySection("types",     p.types)
    summarySection("funcs",     p.funcs)
    summarySection("instances", p.instances)
  }

  private Void spec(DocSpec p)
  {
    pageHeader(p, p.flavor.name.lower) |self|
    {
      specSig(p)
      markdown(p.doc)
    }

    dictSection("meta", p.meta)
    slotsSummary("slots", p.slots)
    slotsSummary("globals", p.globals)
    p.slots.each |x| { if (slotIsOwn(x)) slotDetails(x) }
    p.globals.each |x| { slotDetails(x) }
  }

  private Void instance(DocInstance p)
  {
    pageHeader(p, "instance")
    dictSection("tags", p.instance)
  }

  private Void chapter(DocChapter p)
  {
    // chapter title
    nl.h1.esc(p.title).h1End.nl

    // prev/next navigation (only if multiple chapters)
    if (p.prev != null || p.next != null)
    {
      tag(tagNav).nl
      ul
      if (p.prev != null) li("class='prev'").link(p.prev, "\u00ab $p.prev.dis").liEnd; else li.w("&nbsp;").liEnd
      if (p.next != null) li("class='next'").link(p.next, "$p.next.dis \u00bb").liEnd
      ulEnd
      tagEnd(tagNav).nl.nl
    }

    // body
    markdown(p.doc)
  }

  private Void search(DocSearch p)
  {
    if (searchTitle != null) h1.esc(searchTitle).h1End

    if (searchFormAction != null)
    {
      form("method='get' action='$searchFormAction'")
       .p
       .input("type='text' name='q' value='$p.pattern.toXml' placeholder='$searchPlaceholder'")
       .pEnd
       .formEnd
       .nl
    }

    // number of hits info
    tag(tagSearchInfo).nl
    w(p.info).nl
    tagEnd(tagSearchInfo).nl.nl

    // hits
    tag(tagSearchHits)
    p.hits.each |hit|
    {
      tag(tagSearchHit).nl
      h3
        docTags(hit.tags)
        link(hit.link)
      h3End
      markdown(hit.text)
      tagEnd(tagSearchHit).nl.nl
    }
    tagEnd(tagSearchHits)
  }

  private Void docTags(DocTag[] tags)
  {
    tags.each |tag| { docTag(tag) }
  }

  private Void docTag(DocTag x)
  {
    Str? attrs := null
    tagColor := x.color
    if (tagColor != null) attrs = "style='background-color: $tagColor;'"
    tag(tagTag, attrs)
    esc(x.name)
    tagEnd(tagTag)
  }

//////////////////////////////////////////////////////////////////////////
// Slots
//////////////////////////////////////////////////////////////////////////

  private Void slotsSummary(Str title, Str:DocSlot slots)
  {
    if (slots.isEmpty) return
    tabSection(title)
    props
    propToggle("xetodoc-inherited", "Show inherited slots")
    slots.each |x, n|
    {
      own := slotIsOwn(x)
      attrs := own ? null : "class='xetodoc-inherited'"
      uri := own ?
             ("#" +slotToElemId(x)).toUri :
             DocUtil.slotToUri(x.parent.qname, [n])
      prop(DocLink(uri, n), x.doc.summary, attrs)
    }
    propsEnd
    tabSectionEnd
  }

  private Void slotDetails(DocSlot slot)
  {
    tabSection(slot.name, slotToElemId(slot))
    slotSig(slot)
    markdown(slot.doc)
    nestedSlots(slot)
    tabSectionEnd
  }

  private Void specSig(DocSpec spec)
  {
    tag(tagSlot).code
    esc(spec.name)
    if (spec.base != null) w(" : ").typeRef(spec.base)
    codeEnd.tagEnd(tagSlot).nl
  }

  private Void slotSig(DocSlot slot)
  {
    tag(tagSlot).code
    if (slot.type.isFunc)
      funcSig(slot)
    else
      typeRef(slot.type)
    slotMeta(slot)
    codeEnd.tagEnd(tagSlot).nl
  }

  private Void funcSig(DocSlot slot)
  {
    w("(")
    DocTypeRef? returns
    first := true
    slot.slots.each |p|
    {
      if (p.name == "returns") { returns = p.type; return }
      if (first) first = false
      else w(", ")
      esc(p.name).w(": ")
      typeRef(p.type)
    }
    w(") => ")
    if (returns == null) w("Obj?")
    else typeRef(returns)
  }

  private Void slotMeta(DocSlot slot)
  {
    // remove slots implied in type
    dict := slot.meta.dict
    names := dict.keys
    names.remove("maybe")
    names.remove("ofs")
    if (names.isEmpty) return this

    // sort
    names.sort.moveTo("of", 0)

    // print
    w(" &lt;")
    names.each |n, i|
    {
      if (i > 0) w(", ")
      slotVal(n, dict[n])
    }
    w("&gt;")
    return this
  }

  private Void slotVal(Str name, DocVal val)
  {
    link(DocLink(val.link.uri, name))
    if (!val.isMarker) w(":").propVal(val.toVal)
  }

  private Void nestedSlots(DocSlot spec)
  {
    if (spec.slots.isEmpty || spec.type.isFunc) return

    tag(tagSlotNested).ul
    spec.slots.each |x| { li.nestedSlot(x).liEnd }
    ulEnd.tagEnd(tagSlotNested)
  }

  private This nestedSlot(DocSlot x)
  {
    tag(tagSlot).code

    n := x.name
    if (!XetoUtil.isAutoName(n)) w(n).w(": ")

    typeRef(x.type)

    if (!x.slots.isEmpty)
    {
      w(" { ")
      first := true
      x.slots.each |nest|
      {
        if (first) first = false
        else w(", ")
        esc(nest.name)
        val := nest.meta.get("val")
        if (val != null) { w(":"); propVal(val.toVal) }
      }
      w(" }")
    }

    codeEnd.tagEnd(tagSlot).nl
    return this
  }

  private static Str slotToElemId(DocSlot x) { x.name }

  private static Bool slotIsOwn(DocSlot x) { x.parent == null }

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
    if (p.pageType.includeNav) pageNav(p).nl.nl

    // <xetodoc-main>
    if (p.pageType.useMainLayout) tag(pageMainTag(p)).nl
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

  private Void pageHeader(DocPage p, Str what, |This|? cb := null)
  {
    tabSection(what, "doc-header")
    h1.esc(p.title).h1End
    if (cb != null) cb(this)
    tabSectionEnd
  }

  private Void pageEnd(DocPage p)
  {
    // footer
    if (p.pageType.includeFooter)
    {
      tabSection("", "doc-footer")
      tag(tagFooter).esc(footerText).tagEnd(tagFooter)
      tabSectionEnd
    }

    // </xetodoc-main>
    if (p.pageType.useMainLayout) tagEnd(pageMainTag(p)).nl

    // </xetodoc-page>
    tagEnd(tagPage).nl

    // </body> </html>
    if (fullHtml) bodyEnd.htmlEnd
  }

  private Str pageMainTag(DocPage p)
  {
    if (p.pageType === DocPageType.chapter) return tagChapter
    return tagMain
  }

//////////////////////////////////////////////////////////////////////////
// Sections
//////////////////////////////////////////////////////////////////////////

  private This tabSection(Str title, Str? id := null)
  {
    if (id == null)
    {
      if (title.isEmpty) throw Err()
      id = "doc-$title"
    }
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
    summaries.each |s|
    {
      if (s.isHeading)
        propHeading(s.text.html)
      else
        prop(s.link, s.text)
    }
    propsEnd
    tabSectionEnd

    return this
  }

  private Void dictSection(Str title, DocDict meta)
  {
    if (meta.dict.isEmpty) return
    names := meta.dict.keys.sort
    tabSection(title)
    props
    names.each |n|
    {
      v := meta.dict[n]
      prop(DocLink(v.link.uri, n), v.toVal)
    }
    propsEnd
    tabSectionEnd
  }

//////////////////////////////////////////////////////////////////////////
// Props
//////////////////////////////////////////////////////////////////////////

  private This props() { tag(tagProps).nl }

  private This propsEnd() { tagEnd(tagProps) }

  private This prop(Obj name, Obj? val, Str? attrs := null)
  {
    if (val == null) return this
    tag(tagProp, attrs)
      .tag(tagPropTh).propName(name).tagEnd(tagPropTh)
      .tag(tagPropTd).propVal(val).tagEnd(tagPropTd)
      .tagEnd(tagProp).nl
    return this
  }

  private This propHeading(Str title)
  {
    tr
    .tag(tagPropHeading, "colspan='2'").esc(title)
    .tagEnd(tagPropHeading)
    .trEnd
  }

  private Void propToggle(Str className, Str msg)
  {
    js := "document.querySelectorAll('.${className}').forEach(el => el.classList.toggle('xetodoc-hidden'))"
    tr.tag(tagPropToggle, "colspan='2'")
    label
    input("type=\"checkbox\" checked onchange=\"$js\"")
    w(msg)
    labelEnd
    tagEnd(tagPropToggle).trEnd
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
    if (val is Ref)         return refVal(val)
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

  private This refVal(Ref ref)
  {
    s := ref.id
    if (s.contains("::"))
    {
      uri := DocUtil.qnameToUri(s)
      return linka(uri, uri.name)
    }
    else
    {
      return w("@").w(ref.id)
    }
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
// TypeRef
//////////////////////////////////////////////////////////////////////////

  private This typeRef(DocTypeRef x)
  {
    x.isCompound ? typeRefCompound(x) : typeRefSimple(x)
  }

  private This typeRefSimple(DocTypeRef x)
  {
    a(href(x.uri))
    esc(x.name)
    if (x.isMaybe) w("?")
    aEnd
    return this
  }

  private This typeRefCompound(DocTypeRef x)
  {
    x.ofs.each |of, i|
    {
      if (i > 0) w(" ").w(x.compoundSymbol).w(" ")
      typeRef(of)
    }
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Markdown
//////////////////////////////////////////////////////////////////////////

  private This markdown(DocMarkdown md)
  {
    p.w(md.html).pEnd
  }

//////////////////////////////////////////////////////////////////////////
// Links
//////////////////////////////////////////////////////////////////////////

  private This link(DocLink link, Str? dis := null)
  {
    linka(link.uri, dis ?: link.dis)
  }

  private This linka(Uri uri, Str dis)
  {
    a(href(uri)).esc(dis).aEnd
  }

  private Uri href(Uri uri)
  {
    hrefNorm ? DocUtil.htmlUri(curPage.uri, uri) : uri
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const Str tagPage        := "xetodoc-page"
  static const Str tagNav         := "xetodoc-nav"
  static const Str tagMain        := "xetodoc-main" // two column tab+section
  static const Str tagTab         := "xetodoc-tab"
  static const Str tagSection     := "xetodoc-section"
  static const Str tagProps       := "xetodoc-prop-table"
  static const Str tagProp        := "xetodoc-prop-tr"
  static const Str tagPropTh      := "xetodoc-prop-th"
  static const Str tagPropTd      := "xetodoc-prop-td"
  static const Str tagPropHeading := "xetodoc-prop-heading"
  static const Str tagPropToggle  := "xetodoc-prop-toggle"
  static const Str tagSlot        := "xetodoc-slot"
  static const Str tagSlotNested  := "xetodoc-slot-nested"
  static const Str tagChapter     := "xetodoc-chapter"
  static const Str tagFooter      := "xetodoc-footer"
  static const Str tagSearchInfo  := "xetodoc-search-info"
  static const Str tagSearchHits  := "xetodoc-search-hits"
  static const Str tagSearchHit   := "xetodoc-search-hit"
  static const Str tagTag         := "xetodoc-tag"

  Bool fullHtml := true
  Bool hrefNorm := true
  Str footerText := "footer"
  Str cssFilename := "xetodoc.css"
  Str? searchTitle
  Uri? searchFormAction
  Str searchPlaceholder := "Search docs..."
  private DocPage? curPage
}

