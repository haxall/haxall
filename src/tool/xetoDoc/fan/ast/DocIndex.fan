//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Apr 2025  Brian Frank  Creation
//

using xeto
using haystack
using haystack::Dict

**
** DocIndex is a top level index or appendix page
**
@Js
const class DocIndex : DocPage
{
  ** Constructor
  new make(|This| f) { f(this) }

  ** Return null
  override DocLibRef? lib() { null }

  ** URI relative to base dir to page
  override const Uri uri

  ** Page type
  override DocPageType pageType() { DocPageType.index }

  ** Page title
  const Str title

  ** Doc index groups
  const DocIndexGroup[] groups

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["page"]   = pageType.name
    obj["uri"]    = uri.toStr
    obj["title"]  = title
    obj["groups"] = DocIndexGroup.encodeList(groups)
    return obj
  }

  ** Decode from a JSON object tree
  static DocIndex doDecode(Str:Obj obj)
  {
    DocIndex
    {
      it.uri    = Uri.fromStr(obj.getChecked("uri"))
      it.title  = obj.getChecked("title")
      it.groups = DocIndexGroup.decodeList(obj.getChecked("groups"))
    }
  }
}

**************************************************************************
** DocIndexGroup
**************************************************************************

**
** DocIndexGroup
**
@Js
const class DocIndexGroup
{
  ** Constructor
  new make(Str title, DocSummary[] links)
  {
    this.title = title
    this.links = links
  }

  ** Title of group
  const Str title

  ** Group links
  const DocSummary[] links

  ** Encode a list or null if empty
  static Obj? encodeList(DocIndexGroup[] list)
  {
    if (list.isEmpty) return null
    return list.map |x->Str:Obj| { x.encode }
  }

  ** Encode to a JSON object tree
  Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["title"] = title
    obj.addNotNull("links", DocSummary.encodeList(links))
    return obj
  }

  ** Decode a list or empty if null
  static DocIndexGroup[] decodeList(Obj[]? list)
  {
    if (list == null || list.isEmpty) return DocIndexGroup#.emptyList
    return list.map |x->DocIndexGroup| { decode(x) }
  }

  ** Decode from JSON object tree
  static DocIndexGroup decode(Str:Obj obj)
  {
    title := obj.getChecked("title")
    links := DocSummary.decodeList(obj.get("links"))
    return make(title, links)
  }
}

