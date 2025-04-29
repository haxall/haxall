//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Apr 2025  Brian Frank  Creation
//

using xeto
using xeto::Lib
using haystack
using haystack::Dict

**
** DocIndex is a top level index or appendix page
**
@Js
const class DocIndex : DocPage
{
  ** Simple default implementation (at least for now)
  static DocIndex makeForNamespace(LibNamespace ns)
  {
    // build doc summary for each lib and assign to a group name
    acc := Str:DocSummary[][:]
    ns.libs.each |lib|
    {
      link := DocLink(DocUtil.libToUri(lib.name), lib.name)
      doc  := DocMarkdown(lib.meta["doc"] ?: "")
      summary := DocSummary(link, doc)

      groupName := toGroupName(lib)
      groupList := acc[groupName]
      if (groupList == null) acc[groupName] = groupList = DocSummary[,]
      groupList.add(summary)
    }

    // flatten groups
    groupNames := acc.keys.sort
    ["doc", "sys", "ph"].eachr |n| { groupNames.moveTo(n, 0) }
    groups := DocIndexGroup[,]
    groupNames.each |n| { groups.add(DocIndexGroup(n, acc[n])) }

    return make {
      it.uri    = DocUtil.indexUri
      it.title  = "Doc Index"
      it.groups = groups
    }
  }

  private static Str toGroupName(Lib lib)
  {
    name := lib.name
    toks := name.split('.', false)
    if (toks.size == 1) return name
    if (toks[0] == "cc") return toks[0] + "." + toks[1]
    return toks[0]
  }

  ** Constructor
  new make(|This| f) { f(this) }

  ** Return null
  override DocLibRef? lib() { null }

  ** URI relative to base dir to page
  override const Uri uri := DocUtil.indexUri

  ** Page type
  override DocPageType pageType() { DocPageType.index }

  ** Page title
  const Str title := "Doc Index"

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

