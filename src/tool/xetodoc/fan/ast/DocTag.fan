//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2025  Brian Frank  Creation
//

using xeto

**
** DocTag is used to annotate summaries
**
@Js
const class DocTag
{
  ** Empty list of tags
  static const DocTag[] emptyList := DocTag[,]

  ** Create custom tag
  static DocTag intern(Str name, Int? count := null)
  {
    if (count == null)
    {
      predefined := DocTags.byName.get(name)
      if (predefined != null) return predefined
    }
    return make(name, count)
  }

  ** Internal constructor
  internal new make(Str name, Int? count := null)
  {
    this.name = name
    this.count = count
  }

  ** Tag name
  const Str name

  ** Count if applicable
  const Int? count

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
    obj.addNotNull("count", count)
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
    name  := obj.getChecked("name")
    count := obj.get("count")?.toStr?.toInt
    return intern(name, count)
  }

  ** Icon to use for this tag
  Str icon() { DocUtil.tagToIcon(name) }
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
  static const DocTag lib      := DocTag("lib")
  static const DocTag type     := DocTag("type")
  static const DocTag mixIn    := DocTag("mixin")
  static const DocTag instance := DocTag("instance")
  static const DocTag chapter  := DocTag("chapter")
  static const DocTag sys      := DocTag("sys")
  static const DocTag ph       := DocTag("ph")
  static const DocTag heading  := DocTag("heading")

  static SpecFlavor? toFlavor(DocTag? tag)
  {
    if (tag === type)  return SpecFlavor.type
    if (tag === mixIn) return SpecFlavor.mixIn
    return null
  }

  static DocTag fromFlavor(SpecFlavor f)
  {
    if (f === SpecFlavor.type)  return type
    if (f === SpecFlavor.mixIn) return mixIn
    throw Err(f.name)
  }

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

