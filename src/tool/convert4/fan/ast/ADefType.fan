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
    ext.defs.each |def|
    {
      try
        scanDefType(ast, ext, def)
      catch (Err e)
        Console.cur.err("Cannot scan def: $ext.oldName $def", e)
    }
  }

  private static Void scanDefType(Ast ast, AExt ext, Dict def)
  {
    // check if tag def
    defName := def["def"]?.toStr
    if (defName == null || defName.contains("-") || defName.contains(":")) return

    // get is tag
    baseIs := def["is"]?.toStr
    if (baseIs == null) return

    // only process top-level types
    base := topTypeBase(baseIs)
    if (base == null) return

    // create top type
    name := defName.capitalize
    doc := def["doc"] as Str ?: ""
    t := make(name, doc, base)
    ext.types.add(t)

    // now go thru all ext defs and check for slots
    ext.defs.each |x|
    {
      // check tagOn
      tagOn := x["tagOn"]?.toStr
      if (tagOn == null) return
      if (tagOn != defName) return

      // map to slot AST node
      slot := scanDefSlot(ast, ext, x)
      if (slot == null) return

      // add to our type
      t.slots[slot.name] = slot
    }
  }

  private static AType? topTypeBase(Str baseIs)
  {
    if (baseIs == "conn") return AType("Conn")
    if (baseIs == "connPoint") return AType("ConnPoint")
    return null
  }

  private static ADefSlot? scanDefSlot(Ast ast, AExt ext, Dict def)
  {
    // special handling for common defx
    defx := def["defx"]?.toStr ?: ""
    switch (defx)
    {
      case "uri":      return ADefSlot(defx, AType("Uri?"), "Universal resource identifier")
      case "password": return ADefSlot(defx, AType("Password?"), "Password for authentication")
      case "username": return ADefSlot(defx, AType("Str?"), "Username for authentication")
      case "tz":       return ADefSlot(defx, AType("TimeZone?"), "Timezone")
    }

    name := def["def"]?.toStr
    if (name == null || name.contains("-") || name.contains(":")) return null

    type := AType.fromDef(def)
    doc := def["doc"] as Str ?: ""

    meta := Str:Obj[:]
    of := def["of"]
    if (of != null) meta["of"] = AType(of.toStr.capitalize)

    return ADefSlot(name, type, doc, Etc.dictFromMap(meta))
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

