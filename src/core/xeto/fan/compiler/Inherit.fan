//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//    6 Apr 2023  Brian Frank  Redesign from proto
//

using util

**
** Inherit walks all the objects:
**   - infer type if unspecified
**   - resolves base
**   - handles slot overrides
**   - computes spec flags
**
@Js
internal class Inherit : Step
{
  override Void run()
  {
    if (ast.isSpec)
      inheritSpec(ast)
    else
      inheritVal(ast, null)
    bombIfErr
  }


//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  private Void inheritSpec(ASpec spec)
  {
    // check if already inherited
    if (spec.cslotsRef != null) return

    // if no type was specified during parse, then infer as Dict
    if (spec.typeRef == null)
    {
      if (spec.qname == "sys::Obj") { spec.cslotsRef = noSlots; return }
      spec.typeRef = spec.val == null ? sys.dict : sys.str
// TODO
if (spec.name == "points") spec.typeRef = sys.query
    }

    // if base is not already configured, set it to type
    if (spec.base == null) spec.base = spec.type

    // if base is in my AST, then recursively inherit it first
    base := spec.base
    if (base is ASpec)
    {
      if (stack.containsSame(spec) && !isSys)
      {
        err("Cyclic inheritance: $spec.name", spec.loc)
        spec.cslotsRef = noSlots
      }
      stack.push(spec)
      inheritSpec(base)
      stack.pop
    }

    // now that we have base, compute my flags
    computeFlags(spec)

    // first inherit slots from base type
    acc := Str:CSpec[:]
    acc.ordered = true
    base.cslots.each |slot|
    {
      acc[slot.name] = slot
    }

    // now merge in my own slots
    if (spec.slots != null) spec.slots.each |ASpec slot|
    {
      name := slot.name
      dup := acc[name]
      if (dup != null)
      {
        acc[name] = overrideSlot(dup, slot)
      }
      else
      {
        acc[name] = slot
      }

    }

    // we now have effective slot map
    spec.cslotsRef = acc

    // iherit meta
    inheritMeta(spec)

    // recurse children
    acc.each |slot| { if (slot.isAst) inheritSpec(slot) }
  }

//////////////////////////////////////////////////////////////////////////
// Flags
//////////////////////////////////////////////////////////////////////////

  private Void computeFlags(ASpec x)
  {
    x.flags = isSys ? computeFlagsSys(x) : computeFlagsNonSys(x)
  }

  private Int computeFlagsNonSys(ASpec x)
  {
    // start off with my base type flags
    flags := x.base.flags

    // merge in my own flags
    if (x.meta != null)
    {
      // if maybe is marker set flag, if none then clear flag
      maybe := x.meta.slot("maybe")
      if (maybe != null)
      {
        if (isNone(maybe))
          flags = flags.and(MSpecFlags.maybe.not)
        else
          flags = flags.or(MSpecFlags.maybe)
      }
    }

    return flags
  }

  ** Treat 'sys' itself special using names
  private Int computeFlagsSys(ASpec x)
  {
    flags := 0
    if (metaHas(x, "maybe")) flags = flags.or(MSpecFlags.maybe)
    for (ASpec? p := x; p != null; p = p.base)
    {
      switch (p.name)
      {
        case "Marker": flags = flags.or(MSpecFlags.marker)
        case "Scalar": flags = flags.or(MSpecFlags.scalar)
        case "Seq":    flags = flags.or(MSpecFlags.seq)
        case "Dict":   flags = flags.or(MSpecFlags.dict)
        case "List":   flags = flags.or(MSpecFlags.list)
        case "Query":  flags = flags.or(MSpecFlags.query)
      }
    }
    return flags
  }

//////////////////////////////////////////////////////////////////////////
// Override
//////////////////////////////////////////////////////////////////////////

  private ASpec overrideSlot(CSpec base, ASpec own)
  {
    if (own.typeRef == null)
    {
      // if no type was specified, then inherit base type
      own.typeRef = ARef(own.loc, base.ctype)
    }
    else
    {
      // if base is maybe and my own type is not then clear maybe flag
      if (base.isMaybe && !metaHas(own, "maybe"))
        metaAddNone(own, "maybe")
    }

    // this slot is derived from base slot
    own.base = base
    return own
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  private Void inheritMeta(ASpec spec)
  {
    if (spec.meta == null) return
    inheritVal(spec.meta, null)
  }

  private Void inheritVal(AVal x, ASpec? type)
  {
    // infer type if unspecified
    if (x.typeRef == null)
    {
      if (x.val != null)
        x.typeRef = sys.str
      else
        x.typeRef = sys.dict
    }

    // recurse
    if (x.slots != null) x.slots.each |kid| { inheritVal(kid, null) }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Str:CSpec noSlots() { MSlots.empty.map }

  private ASpec[] stack := [,]
}