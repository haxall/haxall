//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Apr 2025  Brian Frank  Creation
//

using xeto
using haystack

**
** DocIndex is a top level index or appendix page
**
@Js
const class DocIndex : DocPage
{
  ** Simple default implementation
  static DocIndex makeForNamespace(Namespace ns, DocLib[] libPages)
  {
    // build doc summary for each lib and assign to a group name
    acc := Str:DocSummary[][:]
    libPages = libPages.dup.sort |a, b| { a.name <=> b.name }
    libPages.each |libPage|
    {
      link := DocLink(libPage.uri, libPage.title)
      summary := DocSummary(link, libPage.doc.summary, libPage.tags)

      groupName := toGroupName(libPage.name)
      groupList := acc[groupName]
      if (groupList == null) acc[groupName] = groupList = DocSummary[,]
      groupList.add(summary)
    }

    // special handling for fantom
    fantom := acc["fantom"]
    if (fantom != null)
    {
      "sys,docIntro,docLang,docDomkit,docTools".split(',').eachr |n|
      {
        fantom.moveTo(fantom.find { it.link.dis == n }, 0)
      }
    }

    // flatten groups
    groupNames := acc.keys.sort
    ["doc", "sys"].eachr |n| { groupNames.moveTo(n, 0) }
    groupNames.moveTo("fantom", -1)
    groups := DocIndexGroup[,]
    groupNames.each |n| { groups.add(DocIndexGroup(n, acc[n])) }

    return make {
      it.uri    = DocUtil.indexUri
      it.title  = "Doc Index"
      it.groups = groups
    }
  }

  private static Str toGroupName(Str libName)
  {
    toks := libName.split('.', false)
    if (libName == "axon") return "hx"
    if (toks.contains("doc")) return "doc"
    if (toks.size == 1) return libName
    if (toks[0] == "fan") return "fantom"
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
  const override Str title := "Doc Index"

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

