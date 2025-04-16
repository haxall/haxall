//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util

**
** DocPage is base class for documentation pages: libs, specs, instances
**
@Js
const mixin DocPage
{
  ** URI relative to base dir for page
  abstract Uri uri()

  ** Library for this page (or null if top-level indexing)
  abstract DocLibRef? lib()

  ** Enumerated type of this node
  abstract DocPageType pageType()

  ** Encode to a JSON object tree
  abstract Str:Obj encode()

  ** Decode from JSON object tree
  static DocPage decode(Str:Obj obj)
  {
    pageType := DocPageType.fromStr(obj.getChecked("page"))
    switch (pageType)
    {
      case DocPageType.lib:      return DocLib.doDecode(obj)
      case DocPageType.type:     return DocType.doDecode(obj)
      case DocPageType.global:   return DocGlobal.doDecode(obj)
      case DocPageType.instance: return DocInstance.doDecode(obj)
      case DocPageType.chapter:  return DocChapter.doDecode(obj)
      case DocPageType.search:   return DocSearch.doDecode(obj)
      default:                   throw Err("Unknown page type: $pageType")
    }
  }

   ** Dump to JSON
  Void dump(OutStream out := Env.cur.out)
  {
    out.print(JsonOutStream.prettyPrintToStr(encode))
  }
}

**************************************************************************
** DocPageType
**************************************************************************

**
** DocPage enumerated type
**
@Js
enum class DocPageType
{
  lib,
  type,
  global,
  instance,
  chapter,
  search
}

