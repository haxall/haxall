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

  ** Title
  abstract Str title()

  ** Navigation breadcrumbs (from index down to and including this page)
  DocLink[] nav()
  {
    acc := DocLink[,]
    acc.capacity = 4
    acc.add(DocLink(DocUtil.indexUri, "Index"))
    if (lib != null)
    {
      acc.add(DocLink(DocUtil.libToUri(lib.name), lib.name))
      if (pageType !== DocPageType.lib)
        acc.add(DocLink(uri, title))
    }
    return acc
  }

  ** Source code location within xetolib file if applicable
  virtual FileLoc? srcLoc() { null }

  ** Return title for toStr
  override final Str toStr() { title }

  ** Encode to a JSON object tree
  abstract Str:Obj encode()

  ** Decode from JSON object tree
  static DocPage decode(Str:Obj obj)
  {
    pageType := DocPageType.fromStr(obj.getChecked("page"))
    switch (pageType)
    {
      case DocPageType.index:    return DocIndex.doDecode(obj)
      case DocPageType.lib:      return DocLib.doDecode(obj)
      case DocPageType.spec:     return DocSpec.doDecode(obj)
      case DocPageType.instance: return DocInstance.doDecode(obj)
      case DocPageType.chapter:  return DocChapter.doDecode(obj)
      case DocPageType.search:   return DocSearch.doDecode(obj)
      default:                   throw Err("Unknown page type: $pageType")
    }
  }

  ** Encode to an in-memory buffer
  Buf encodeToBuf()
  {
    buf := Buf()
    JsonOutStream(buf.out).writeJson(encode)
    return buf.flip
  }

  ** Encode to JSON file
  File encodeToFile()
  {
    encodeToBuf.toFile(uri)
  }

  ** Decode from JSON file
  static DocPage decodeFromFile(File file)
  {
    file.withIn |in| { decode(JsonInStream(in).readJson) }
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
  index,
  lib,
  spec,
  instance,
  chapter,
  search
}

