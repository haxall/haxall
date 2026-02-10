//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using axon

**
** AST type spec synthesized from defs
**
class ADefType
{
  static Void scanExt(Ast ast, AExt ext)
  {
    ext.defs.each |def, i|
    {
      try
      {
        types := scanDefType(ast, ext, def)
        if (types == null) return
        ext.types.addAll(types)
        ext.used[i] = true
      }
      catch (Err e) Console.cur.err("Cannot scan def: $ext.oldName $def", e)
    }
  }

  private static ADefType[]? scanDefType(Ast ast, AExt ext, Dict def)
  {
    // check if tag def
    defName := def["def"]?.toStr
    if (defName == null || defName.contains("-") || defName.contains(":")) return null

    // now go thru all ext defs and get tag defs
    tags := Dict[,]
    ext.defs.each |x, i|
    {
      // check tagOn
      if (!isTagOnMatch(x["tagOn"], defName)) return
      tags.add(x)
      ext.used[i] = true
    }

    return fromDef(defName, def, tags)
  }

  static ADefType[]? fromDef(Str defName, Dict def, Dict[] tags)
  {
    // get is tag
    baseIs := def["is"]
    if (baseIs == null) return null

    // only process top-level types
    base := topTypeBase(baseIs)
    if (base == null) return null

    // create top type
    name := defName.capitalize
    doc := def["doc"] as Str ?: ""
    t := make(name, doc, base)

    // add marker tag slot
    markerName := defName
    t.slots[markerName] = ADefSlot(markerName, AType("Marker"), "Marker tag for $name type")

    // now map tags to slots
    enumTypes := ADefType[,]
    tags.each |tag|
    {
      // map to slot AST node
      slot := scanDefSlot(tag)
      if (slot == null) return

      // add to our type
      t.slots[slot.name] = slot

      // if enum tag, then generate as new Enum type
      if (tag.has("enum") && slot.name != "tz")
        enumTypes.add(scanDefEnum(slot.name, tag))
    }

    return [t].addAll(enumTypes)
  }

  private static AType? topTypeBase(Obj baseIs)
  {
    if (baseIs is List) baseIs = ((List)baseIs).first
    x := baseIs.toStr
    if (x == "entity") return AType("Entity")
    if (x == "point") return AType("Entity")
    if (x == "conn") return AType("Conn")
    if (x == "connPoint") return AType("ConnPoint")
    return null
  }

  private static Bool isTagOnMatch(Obj? val, Str defName)
  {
    if (val == null) return false
    if (val?.toStr == defName) return true
    if (val is List) return ((Obj?[])val).any |x| { x?.toStr == defName }
    return false
  }

  private static ADefSlot? scanDefSlot(Dict def)
  {
    // special handling for common defx
    defx := def["defx"]?.toStr ?: ""
    switch (defx)
    {
      case "disabled": return ADefSlot(defx, AType("Marker?"), "Set into disabled state")
      case "password": return ADefSlot(defx, AType("Password?"), "Password for authentication")
      case "tz":       return ADefSlot(defx, AType("TimeZone?"), "Timezone")
      case "username": return ADefSlot(defx, AType("Str?"), "Username for authentication")
      case "uri":      return ADefSlot(defx, AType("Uri?"), "Universal resource identifier")
    }

    name := def["def"]?.toStr
    if (name == null || name.contains("-") || name.contains(":")) return null

    type := AType.fromDef(def)
    doc := def["doc"] as Str ?: ""

    meta := Str:Obj[:]
    of := def["of"]
    if (of != null) meta["of"] = AType(of.toStr.capitalize)

    if (def.has("transient")) meta["transient"] = Marker.val

    if (def.has("val")) meta["val"] = def["val"]

    return ADefSlot(name, type, doc, Etc.dictFromMap(meta))
  }

  private static ADefType scanDefEnum(Str parentName, Dict def)
  {
    name := parentName.capitalize
    tdoc := def["doc"] as Str ?: "String enums for $parentName"
    t := make(name, tdoc, AType("Enum"))
    t.slots.ordered = true

    ConvertUtil.parseEnum(def["enum"]).each |v, n|
    {
      doc := v["doc"] ?: ""
      meta := Etc.dict0
      if (!Etc.isTagName(n))
      {
        meta = Etc.dict1("key", n)
        n = Etc.toTagName(n)
      }
      s := ADefSlot(n, AType("Marker"), doc, meta)
      t.slots[s.name] = s
    }

    return t
  }

  new make(Str name, Str doc, AType base)
  {
    this.name = name
    this.doc  = doc
    this.base = base
  }

  const Str name
  const Str doc
  const AType base
  Str:ADefSlot slots := [:]
}

**************************************************************************
** ADefSlot
**************************************************************************

const class ADefSlot
{
  new make(Str name, AType type, Str doc, Dict meta := Etc.dict0)
  {
    this.name = name
    this.type = type
    this.doc  = doc
    this.meta = meta
  }

  const Str name
  const AType type
  const Str doc
  const Dict meta

  override Str toStr() { "$name: $type" }
}

