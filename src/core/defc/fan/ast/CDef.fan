//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Dec 2018  Brian Frank  Creation
//

using haystack
using def

**
** CDef
**
class CDef
{
  internal new make(CLoc loc, CLib lib, CSymbol symbol, Dict declared)
  {
    this.loc = loc
    this.lib = lib
    this.symbol = symbol
    this.declared = declared
  }

  internal new makeLib(CLoc loc, CSymbol symbol, Dict declared)
  {
    this.loc = loc
    this.lib = this
    this.symbol = symbol
    this.declared = declared
  }

  ** File location of source definition
  const CLoc loc

  ** Parent lib
  CLib lib

  ** Is this the library def itself
  Bool isLib() { this === lib }

  ** Symbol key
  const CSymbol symbol

  ** Simple name
  Str name() { symbol.name }

  ** Symbol type (which infers def type)
  SymbolType type() { symbol.type }

  ** Is feature key
  Bool isKey() { type.isKey }

  ** Resolved defs for each part in the symbol computed in Resolve
  CDefParts? parts

  ** Once a def is put in fault its skipped from further processing
  Bool fault

  ** Key def parts
  CKeyParts key() { parts.key }

  ** Compose def parts
  CConjunctParts conjunct() { parts.conjunct }

  ** To pass thru DefBuilder via BDef
  Obj? aux

  ** Declared meta from source
  const Dict declared

  ** Normalized meta computed in Resolve, Normalize
  [Str:CPair]? meta

  ** Does this def have the given tag
  Bool has(Str name) { meta[name] != null }

  ** Get meta CPair value
  Obj? get(Str name) { meta[name]?.val }

  ** Set meta CPair
  Void set(CDef tag, Obj val) { meta[tag.name] = CPair(tag.name, tag, val) }

  ** Declared only supertypes (Taxonify)
  CDef[]? supertypes

  ** Flattened list of all defs which fit this instance including this (Taxonify)
  CDef[]? inheritance

  ** Bit mask of key inheritance types (Taxonify)
  Int flags

  // inheritance flags
  Bool isAssociation()  { flags.and(CDefFlags.association)  != 0 }
  Bool isChoice()       { flags.and(CDefFlags.choice)       != 0 }
  Bool isEntity()       { flags.and(CDefFlags.entity)       != 0 }
  Bool isFeature()      { flags.and(CDefFlags.feature)      != 0 }
  Bool isList()         { flags.and(CDefFlags.list)         != 0 }
  Bool isMarker()       { flags.and(CDefFlags.marker)       != 0 }
  Bool isRef()          { flags.and(CDefFlags.ref)          != 0 }
  Bool isRelationship() { flags.and(CDefFlags.relationship) != 0 }
  Bool isVal()          { flags.and(CDefFlags.val)          != 0 }

  ** Return if this def is a fit/subtype of that
  Bool fits(CDef that) { inheritance.contains(that) }

  ** Sort by symbol name
  override Int compare(Obj that) { toStr <=> that.toStr }

  ** Return symbol name
  override Str toStr() { symbol.toStr }

  ** Return symbol name
  virtual Str dis() { symbol.toStr }

  ** Documentation computed in Normalize
  CFandoc fandoc := CFandoc.none

  ** Children prototypes
  CProto[]? children

  ** Is nodoc flag configured
  Bool isNoDoc() { has("nodoc") }

  ** Flag used by Inherit for recursion
  internal Bool isInherited

  ** Actual def from namespace
  Def actual(Namespace ns)
  {
    if (actualRef == null) actualRef = ns.def(symbol.toStr)
    return actualRef
  }
  internal Def? actualRef

  ** If run thru GenDocEnv
  DocDef? doc
}

**************************************************************************
** CDefFlags
**************************************************************************

const class CDefFlags
{
  static Int compute(CDef def)
  {
    mask := 0
    def.inheritance.each |base|
    {
      switch (base.name)
      {
        case "association":  mask = mask.or(association)
        case "choice":       mask = mask.or(choice)
        case "entity":       mask = mask.or(entity)
        case "feature":      mask = mask.or(feature)
        case "list":         mask = mask.or(list)
        case "marker":       mask = mask.or(marker)
        case "ref":          mask = mask.or(ref)
        case "relationship": mask = mask.or(relationship)
        case "val":          mask = mask.or(val)
      }
    }
    return mask
  }

  static Str flagsToStr(Int flags)
  {
    s := StrBuf()
    CDefFlags#.fields.each |f|
    {
      if (f.isStatic && f.type == Int# && flags.and(f.get(null)) != 0)
        s.join(f.name, ",")
    }
    return s.toStr + " 0x" + flags.toHex
  }

  internal static const Int association  := 0x0001
  internal static const Int choice       := 0x0002
  internal static const Int entity       := 0x0004
  internal static const Int feature      := 0x0008
  internal static const Int list         := 0x0010
  internal static const Int marker       := 0x0020
  internal static const Int ref          := 0x0040
  internal static const Int relationship := 0x0080
  internal static const Int val          := 0x0100
}

**************************************************************************
** CPair
**************************************************************************

class CPair
{
  new make(Str name, CDef? tag, Obj val)
  {
    this.name = name
    this.tag  = tag
    this.val  = val
  }

  const Str name

  Obj val

  CDef? tag

  Bool isInherited() { tag != null && tag.declared.missing("notInherited") }

  Bool isAccumulate() { tag != null && tag.declared.has("accumulate") }

  CPair accumulate(CPair that)
  {
    if (tag !== that.tag) throw Err(name)
    if (!tag.isList) throw Err("Cannot accumulate non-list tag: $tag")
    return make(name, tag, DefUtil.accumulate(this.val, that.val))
  }

  Obj tagOrName() { tag ?: name }

  override Str toStr() { "$name: $val" }

}