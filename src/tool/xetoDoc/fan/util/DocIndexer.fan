//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2025  Brian Frank  Creation
//

using markdown
using xeto
using haystack

**
** DocIndexer is used to crawl the AST of documents to generate a search index
**
abstract class DocIndexer
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
    doAdd(x.uri, x.lib, DocIndexerSectionType.type, [x.qname, x.name], x.qname, x.doc)
    x.eachSlotOwn |slot| { addSlot(x, slot) }
  }

  ** Add DocSlot section to index
  virtual Void addSlot(DocSpec parent, DocSlot slot)
  {
    uri   := parent.uri + `#${slot.name}`
    qname := parent.qname + "." + slot.name
    doAdd(uri, parent.lib, DocIndexerSectionType.slot, [qname, slot.name], qname, slot.doc)
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

    // parse markdown and find all headings
    doc := x.doc.parse
    headings := doc.findAll { it is Heading }

    // find all the content between each heading and render it is a plaintext
    renderer := TextRenderer()
    headings.each |Heading heading, i|
    {
      // get all the text between headings
      bodyDoc := Document()
      Node.eachBetween(heading, headings.getSafe(i+1)) |node| { bodyDoc.appendChild(node) }

      uri   := x.uri + `#${heading.anchor}`
      type  := DocIndexerSectionType.heading(heading.level)
      title := renderer.render(heading)
      body  := renderer.render(bodyDoc)
      doAdd(uri, x.lib, type, Str#.emptyList, title, body)
    }
  }

  private Void doAdd(Uri uri, DocLibRef? lib, DocIndexerSectionType type, Str[] keys, Str title, Obj body)
  {
    add(DocIndexerSection {
      it.uri   = uri
      it.lib   = lib
      it.type  = type
      it.keys  = keys
      it.title = title
      it.body  = body as Str ?: ((DocMarkdown)body).plain
    })
  }

//////////////////////////////////////////////////////////////////////////
// Abstract
//////////////////////////////////////////////////////////////////////////

  ** Add section to index
  abstract Void add(DocIndexerSection section)
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

  ** Debug string
  override Str toStr() { "$uri $type $keys $title" }
}

**************************************************************************
** DocIndexerSectionType
**************************************************************************

**
** DocIndexerSectionType
**
enum class DocIndexerSectionType
{
  lib      (0.8f),
  type     (0.7f),
  global   (0.6f),
  slot     (0.1f),
  instance (0.0f),
  chapter  (1.0f),
  h1       (0.90f),
  h2       (0.91f),
  h3       (0.92f)

  private new make(Float weight)
  {
    this.weight = weight
    this.tag    = (name[0] == 'h' && name.size == 2) ? "chapter" : name
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

