//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2025  Brian Frank  Creation
//

using xeto
using haystack

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

  ** Title
  override Str title() { "Search" }

  ** Search pattern
  const Str pattern

  ** Additional info to display about search or empty string
  const Str info := ""

  ** Search hits
  const DocSummary[] hits

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["page"]    = pageType.name
    obj["pattern"] = pattern
    obj["info"]    = info
    obj.addNotNull("hits", DocSummary.encodeList(hits))
    return obj
  }

  ** Decode from a JSON object tree
  static DocSearch doDecode(Str:Obj obj)
  {
    DocSearch
    {
      it.pattern = obj.getChecked("pattern")
      it.info    = obj["info"] as Str ?: ""
      it.hits    = DocSummary.decodeList(obj["hits"])
    }
  }
}

