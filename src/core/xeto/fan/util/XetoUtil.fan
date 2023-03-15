//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Feb 2023  Brian Frank  Creation
//

using data
using util

**
** Utility functions
**
@Js
internal const class XetoUtil
{

//////////////////////////////////////////////////////////////////////////
// Naming
//////////////////////////////////////////////////////////////////////////

  ** Return if valid spec name
  static Bool isSpecName(Str n)
  {
    if (n.isEmpty) return false
    ch := n[0]

    // _123
    if (ch == '_') return n.all |c, i| { i == 0 || c.isDigit }

    // Foo_Bar_123
    if (!ch.isAlpha) return false
    return n.all |c| { c.isAlphaNum || c == '_' }
  }

//////////////////////////////////////////////////////////////////////////
// Inherit Meta
//////////////////////////////////////////////////////////////////////////

  ** Inherit spec meta data
  static DataDict inheritMeta(MSpec spec)
  {
    own := spec.own

    base := spec.base as XetoSpec
    if (base == null) return own

    // walk thru base tags and map tags we inherit
    acc := Str:Obj[:]
    baseSize := 0
    base.m.meta.each |v, n|
    {
      baseSize++
      if (isMetaInherited(n)) acc[n] = v
    }

    // if we inherited all of the base tags and
    // I have none of my own, then reuse base meta
    if (acc.size == baseSize && own.isEmpty)
      return base.m.meta

    // merge in my own tags
    if (!own.isEmpty)
      own.each |v, n| { acc[n] = v }

    return spec.env.dictMap(acc)
  }

  static Bool isMetaInherited(Str name)
  {
    // we need to make this use reflection at some point
    if (name == "abstract") return false
    if (name == "sealed") return false
    if (name == "maybe") return false
    return true
  }

//////////////////////////////////////////////////////////////////////////
// Inherit Slots
//////////////////////////////////////////////////////////////////////////

  ** Inherit spec slots
  static MSlots inheritSlots(MSpec spec)
  {
    own := spec.slotsOwn
    supertype := spec.base

    if (supertype == null) return own
    if (own.isEmpty) return supertype.slots

    // add supertype slots
    acc := Str:XetoSpec[:]
    acc.ordered = true
    supertype.slots.each |s|
    {
      acc[s.name] = s
    }

    // add in my own slots
    own.each |s|
    {
      n := s.name
      inherit := acc[n]
      if (inherit != null) s = overrideSlot(inherit, s)
      acc[n] = s
    }

    return MSlots(acc)
  }

  ** Merge inherited slot 'a' with override slot 'b'
  static XetoSpec overrideSlot(XetoSpec a, XetoSpec b)
  {
    XetoSpec(MSpec(b.loc, b.parent, b.name, a, b.type, b.own, b.slotsOwn, b.m.flags))
  }

//////////////////////////////////////////////////////////////////////////
// Is-A
//////////////////////////////////////////////////////////////////////////

  ** Return if a is-a b
  static Bool isa(XetoSpec a, XetoSpec b)
  {
    // check direct inheritance
    for (DataSpec? x := a; x != null; x = x.base)
      if (x === b) return true

    // if A is "maybe" type, then it also matches None
    if (b.isNone && a.isMaybe) return true

    // if A is And type, then check any of A.ofs is B
    if (a.isAnd )
    {
      ofs := a.get("ofs", null) as DataSpec[]
      if (ofs != null && ofs.any |x| { x.isa(b) }) return true
    }

    // if B is Or type, then check if A is any of B.ofs
    if (b.isOr)
    {
      ofs := b.get("ofs", null) as DataSpec[]
      if (ofs != null && ofs.any |x| { a.isa(x) }) return true
    }

    return false
  }

//////////////////////////////////////////////////////////////////////////
// Derive
//////////////////////////////////////////////////////////////////////////

  ** Dervice a new spec from the given base, meta, and map
  static DataSpec derive(XetoEnv env, Str name, XetoSpec base, DataDict meta, [Str:DataSpec]? slots)
  {
    // sanity checking
    if (!isSpecName(name)) throw ArgErr("Invalid spec name: $name")
    if (!base.isDict)
    {
      if (slots != null && !slots.isEmpty) throw ArgErr("Cannot add slots to non-dict type: $base")
    }

    spec := XetoSpec()
    m := MDerivedSpec(env, name, base, meta, deriveSlots(env, spec, slots), deriveFlags(base, meta))
    XetoSpec#m->setConst(spec, m)
    return spec
  }

  private static Int deriveFlags(XetoSpec base, DataDict meta)
  {
    flags := base.m.flags
    if (meta.has("maybe")) flags = flags.or(MSpecFlags.maybe)
    return flags
  }

  private static MSlots deriveSlots(XetoEnv env, XetoSpec parent, [Str:DataSpec]? slotsMap)
  {
    if (slotsMap == null || slotsMap.isEmpty) return MSlots.empty

    derivedMap := slotsMap.map |XetoSpec base, Str name->XetoSpec|
    {
      XetoSpec(MSpec(FileLoc.synthetic, parent, name, base, base.type, env.dict0, MSlots.empty, base.m.flags))
    }

    return MSlots(derivedMap)
  }
}

