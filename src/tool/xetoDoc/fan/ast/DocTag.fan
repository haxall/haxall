//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2025  Brian Frank  Creation
//

**
** DocTag is used to annotate search hit summaries
**
@Js
const class DocTag
{
  ** Create by name
  static new fromStr(Str name)
  {
    DocTags.byName.get(name) ?: makeCustom(name)
  }

  ** Create custom tag
  static DocTag makeCustom(Str name) { doMake(name) }

  ** Internal constructor
  internal new doMake(Str name) { this.name = name }

  ** Tag name
  const Str name

  ** Return tag name
  override Str toStr() { name }

  ** Encode a list or null if empty
  static Obj? encodeList(DocTag[] list)
  {
    if (list.isEmpty) return null
    return list.map |x->Str:Obj| { x.encode }
  }

  ** Encode to a JSON object tree
  Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["name"] = name
    return obj
  }

  ** Decode a list or empty if null
  static DocTag[] decodeList(Obj[]? list)
  {
    if (list == null || list.isEmpty) return DocTag#.emptyList
    return list.map |x->DocTag| { decode(x) }
  }

  ** Decode from JSON object tree
  static DocTag? decode([Str:Obj]? obj)
  {
    if (obj == null) return null
    name := obj.getChecked("name")
    return fromStr(name)
  }
}

**************************************************************************
** DocTags
**************************************************************************

**
** Constant tags
**
@Js
const class DocTags
{
  static const DocTag lib      := DocTag.makeCustom("lib")
  static const DocTag type     := DocTag.makeCustom("type")
  static const DocTag global   := DocTag.makeCustom("global")
  static const DocTag slot     := DocTag.makeCustom("slot")
  static const DocTag instance := DocTag.makeCustom("instance")
  static const DocTag chapter  := DocTag.makeCustom("chapter")

  static once Str:DocTag byName()
  {
    acc := Str:DocTag[:]
    DocTags#.fields.each |f|
    {
      if (!f.isStatic) return
      v := f.get(null) as DocTag
      if (v != null) acc[v.name] = v
    }
    return acc.toImmutable
  }
}

