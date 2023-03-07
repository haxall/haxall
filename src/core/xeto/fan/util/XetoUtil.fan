//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Feb 2023  Brian Frank  Creation
//

using data

**
** Utility functions
**
@Js
internal const class XetoUtil
{

//////////////////////////////////////////////////////////////////////////
// Inherit Meta
//////////////////////////////////////////////////////////////////////////

  ** Inherit spec meta data
  static DataDict inheritMeta(MSpec spec)
  {
    own := spec.own

    base := spec.base as XetoSpec
    if (base == null) return own

    if (own.isEmpty) return base.m.meta

    acc := Str:Obj[:]
    base.m.meta.each |v, n|
    {
      if (isMetaInherited(n)) acc[n] = v
    }
    own.each |v, n|
    {
      acc[n] = v
    }
    return spec.env.dict(acc)
  }

  static Bool isMetaInherited(Str name)
  {
    // we need to make this use reflection at some point
    if (name == "abstract") return false
    if (name == "sealed") return false
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
    supertype.slots.each |s, n|
    {
      acc[n] = s
    }

    // add in my own slots
    own.each |s, n|
    {
      inherit := acc[n]
      if (inherit != null) s = overrideSlot(inherit, s)
      acc[n] = s
    }

    return MSlots(acc)
  }

  ** Merge inherited slot 'a' with override slot 'b'
  static XetoSpec overrideSlot(XetoSpec a, XetoSpec b)
  {
    XetoSpec(MSpec(b.loc, b.parent, b.name, a, b.type, b.own, b.slotsOwn))
  }

//////////////////////////////////////////////////////////////////////////
// Is-A
//////////////////////////////////////////////////////////////////////////

  ** Return if a is-a b
  static Bool isa(XetoSpec a, XetoSpec b)
  {
    // check direct inheritance
    and := a.m.env.sys.and
    maybe := a.m.env.sys.maybe
    isAnd := false
    isMaybe := false
    for (DataSpec? x := a; x != null; x = x.base)
    {
      if (x === b) return true

      if (x === and) isAnd = true
      else if (x === maybe) isMaybe = true
    }

    // if A is "maybe" type, then check his "of"
    if (isMaybe)
    {
      of := a.get("of", null) as DataSpec
      if (of != null) return of.isa(b)
    }

    // if A is "and" type, then check his "ofs"
    if (isAnd)
    {
      ofs := a.get("ofs", null) as DataSpec[]
      if (ofs != null && ofs.any |x| { x.isa(b) }) return true
    }

    return false
  }

}

