//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2025  Brian Frank  Creation
//

using xeto
using haystack
using haystack::Dict

**
** DocSearch displays a page of search results
**
@Js
const class DocSearch : DocPage
{
  ** Constructor
  new make(|This| f) { f(this) }

  ** Return null
  override DocLibRef? lib() { null }

  ** URI relative to base dir to page
  override Uri uri() { `search` }

  ** Page type
  override DocPageType pageType() { DocPageType.search }

  ** Search pattern
  const Str pattern

  ** Search hits
  const DocSummary[] hits

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["page"]    = pageType.name
    obj["pattern"] = pattern
    obj["hits"]    = DocSummary.encodeList(hits)
    return obj
  }

  ** Decode from a JSON object tree
  static DocSearch doDecode(Str:Obj obj)
  {
    DocSearch
    {
      it.pattern = obj.getChecked("pattern")
      it.hits    = DocSummary.decodeList(obj.getChecked("hits"))
    }
  }
}

**************************************************************************
** DocSearchEngine
**************************************************************************

**
** Search engine interface
**
const mixin DocSearchEngine
{
  ** Search the given pattern and return search page
  abstract DocSearch search(Str pattern, Dict opts)
}

**************************************************************************
** DocSearchIndexer
**************************************************************************

**
** DocSearchCrawler is used to crawl the AST and generate callbacks
** that be used to build a text index on the documentation
**
/* TODO
@Js
mixin DocSearchIndexer
{
  ** Start indexing of a unique documentation or doc section
  virtual Void startDoc(DocSummary summary) { echo("\n--- $summary") }

  ** Index given text for current document
  virtual Void add(DocSearchIndexMode mode, Str text) { echo("$mode $text") }

  ** End indexing the current document
  virtual Void endDoc() { echo("---") }
}

**************************************************************************
** DocSearchIndexMode
**************************************************************************

**
** DocSearchIndexMode is used to indicate how to index text
**
@Js
const class DocSearchIndexMode
{
  static const DocSearchIndexMode qname := make(0.9f, true)

  ** Constructor
  new make(Float w, Bool u) {weight = w; unscanned = u}

  ** Weight from 0.0 to 1.0
  const Float weight := 0.2f

  ** Do not scan the text, rather index it raw (like a qname)
  const Bool unscanned

  ** Debug string
  override Str toStr()
  {
    s := weight.toStr
    if (unscanned) s += " unscanned"
    return s
  }
}
*/

