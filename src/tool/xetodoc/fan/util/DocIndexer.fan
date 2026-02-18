//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2025  Brian Frank  Creation
//

using markdown
using util
using xml
using xeto
using haystack

**
** DocIndexer is used to crawl the AST of documents to generate a search index
**
class DocIndexer
{

//////////////////////////////////////////////////////////////////////////
// Pages
//////////////////////////////////////////////////////////////////////////

  ** Add page to index
  virtual Void addPage(DocPage page)
  {
    switch (page.pageType)
    {
      case DocPageType.index:    return
      case DocPageType.lib:      addLib(page)
      case DocPageType.spec:     addSpec(page)
      case DocPageType.instance: addInstance(page)
      case DocPageType.chapter:  addChapter(page)
      case DocPageType.search:   return
      default:                   throw Err(page.pageType.toStr)
    }
  }

  ** Add DocLib page to index
  virtual Void addLib(DocLib x)
  {
    doAdd(x.uri, x.lib, DocIndexerSectionType.lib, [x.name], x.name, x.doc)
  }

  ** Add DocType page to index
  virtual Void addSpec(DocSpec x)
  {
    type      := x.flavor.isMixin ? DocIndexerSectionType.mixIn : DocIndexerSectionType.type
    extraTags := x.tags.mapNotNull |t->Str?| { t.name == type.tag ? null : t.name }
    qname     := x.qname
    if (qname.startsWith("fan.")) qname = qname[4..-1]
    doAdd(x.uri, x.lib, type, [x.qname, x.name], qname, x.doc, extraTags)
    x.eachSlotOwn |slot| { addSlot(x, qname, slot, extraTags) }
  }

  ** Add DocSlot section to index
  virtual Void addSlot(DocSpec parent, Str parentQname, DocSlot slot, Str[] extraTags)
  {
    uri := parent.uri + `#${slot.name}`
    if (parent.name == "Funcs")
    {
      qname := parent.lib.name + "::" + slot.name
      doAdd(uri, parent.lib, DocIndexerSectionType.func, [qname, slot.name], qname, slot.doc, extraTags)
    }
    else
    {
      qname := parentQname + "." + slot.name
      doAdd(uri, parent.lib, DocIndexerSectionType.slot, [qname, slot.name], qname, slot.doc, extraTags)
    }
  }

  ** Add DocInstance page to index
  virtual Void addInstance(DocInstance x)
  {
    doAdd(x.uri, x.lib, DocIndexerSectionType.instance, [x.qname, x.name], x.qname, DocMarkdown.empty)
  }

  ** Add DocChapter page to index
  virtual Void addChapter(DocChapter x)
  {
    // index chapter qname/name itself
    doAdd(x.uri, x.lib, DocIndexerSectionType.chapter, [x.qname, x.name], x.name, "")

    // parse html and find all headings
    try
    {
      DocIndexerHtmlParser().parseSections(x.doc.html) |elem, title, body|
      {
        uri := x.uri
        anchor := elem.attr("id", false)
        if (anchor != null) uri = uri + `#${anchor.val}`
        level := elem.name[1].fromDigit
        type  := DocIndexerSectionType.heading(level)
        doAdd(uri, x.lib, type, Str#.emptyList, title, body)
      }
    }
    catch (Err e) Console.cur.err("Cannot index $x.qname", e)
  }

  private Void doAdd(Uri uri, DocLibRef? lib, DocIndexerSectionType type, Str[] keys, Str title, Obj body,
                     Str[] extraTags := Str#.emptyList)
  {
    add(DocIndexerSection {
      it.uri       = uri
      it.lib       = lib
      it.type      = type
      it.keys      = keys
      it.title     = title
      it.body      = body as Str ?: parseHtmlToPlainText(uri, body)
      it.extraTags = extraTags
    })
  }

  private Str parseHtmlToPlainText(Uri uri, DocMarkdown body)
  {
    try
      return DocIndexerHtmlParser().parseToPlainText(body.html)
    catch (Err e)
      Console.cur.err("Cannot index $uri", e)
    return body.html
  }

//////////////////////////////////////////////////////////////////////////
// Abstract
//////////////////////////////////////////////////////////////////////////

  ** Add section to index
  virtual Void add(DocIndexerSection section) {}
}

**************************************************************************
** DocIndexerHtmlParser
**************************************************************************

**
** DocIndexerHtmlParser is a helper class used to parse the HTML generated
** from markdown back into XML and plaintext for search indexing.
**
class DocIndexerHtmlParser
{
  ** Parse the HTML by section and call with h1/h2/h3 element, title, body
  Str parseToPlainText(Str html)
  {
    buf := StrBuf()
    parser := XParser(html.in)
    while (parser.next != null)
    {
      elem := parser.parseElem
      flattenToStrBuf(elem, buf)
    }
    return buf.toStr
  }

  ** Parse the HTML by section and call with h1/h2/h3 element, title, body
  Void parseSections(Str html, |XElem head, Str title, Str body| f)
  {
    XElem? curElem := null
    curTitle := ""
    buf := StrBuf()
    parser := XParser(html.in)
    while (parser.next != null)
    {
      // process next top-level element
      elem := parser.parseElem
      if (isHeading(elem))
      {
        // if heading, then finish current section and reset
        if (curElem != null) f(curElem, curTitle, buf.toStr)
        curElem = elem.copy
        curTitle = flattenToStr(elem)
        buf.clear
      }
      else
      {
        // append text into current section
        flattenToStrBuf(elem, buf)
      }
    }

    // finish last section
    if (!buf.isEmpty) f(curElem ?: XElem("h1"), curTitle, buf.toStr)
  }


  ** Flatten element to plain t4ext
  private static Bool isHeading(XElem elem)
  {
    name := elem.name
    return name.size == 2 && name[0] == 'h' && name[1].isDigit
  }

  ** Flatten element to plain t4ext
  private static Str flattenToStr(XElem elem)
  {
    buf := StrBuf()
    flattenToStrBuf(elem, buf)
    return buf.toStr
  }

  ** Flatten element to plain text
  private static Void flattenToStrBuf(XNode node, StrBuf buf)
  {
    if (node is XText)
    {
      str := ((XText)node).val
      if (!buf.isEmpty) buf.addChar(' ')
      buf.addTrim(str.trim)
    }
    else if (node is XElem)
    {
      ((XElem)node).each |kid| { flattenToStrBuf(kid, buf) }
    }
  }
}

**************************************************************************
** DocIndexerSection
**************************************************************************

**
** DocIndexerSection is one directly addressable section
**
const class DocIndexerSection
{
  ** It-block constructor
  new make(|This| f) { f(this) }

  ** Section identifier (might have fragment identifier)
  const Uri uri

  ** Library version if section is under a library
  const DocLibRef? lib

  ** Section type for boost weighting
  const DocIndexerSectionType type

  ** Exact keywords such as qnames to index **without** parsing text
  const Str[] keys

  ** Title to index with parsing; should also be shown on retrevial
  const Str title

  ** Body of section to index with parsing
  const Str body

  ** Additional tags beyond the section type tag (e.g. "fantom")
  const Str[] extraTags := Str#.emptyList

  ** All tags (type is always the first tag)
  Str[] tags() { [type.tag].addAll(extraTags) }

  ** Debug string
  override Str toStr() { "$uri | $type $type.weight | $keys" }
}

**************************************************************************
** DocIndexerSectionType
**************************************************************************

**
** DocIndexerSectionType
**
enum class DocIndexerSectionType
{
  lib      (0.9f),
  type     (0.7f),
  mixIn    (0.5f),
  global   (0.6f),
  func     (0.4f),
  slot     (0.4f),
  instance (0.0f),
  chapter  (1.0f),
  h1       (0.90f),
  h2       (0.91f),
  h3       (0.92f)

  private new make(Float weight)
  {
    this.weight = weight
    if (name == "mixIn")
      this.tag = "mixin"
    else
      this.tag = (name[0] == 'h' && name.size == 2) ? "chapter" : name
  }

  ** Boost weight from 1.0 (most important) to 0.0 (least important)
  const Float weight

  ** Best tag to use for section type
  const Str tag

  static DocIndexerSectionType heading(Int level)
  {
    if (level == 1) return h1
    if (level == 2) return h2
    return h3
  }

}

