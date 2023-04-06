//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//    6 Apr 2023  Brian Frank  Creation
//

using util

**
** Inherit slots from base type
**
@Js
internal class Inherit : Step
{
  override Void run()
  {
    inherit(lib)
    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Inherit
//////////////////////////////////////////////////////////////////////////

  private Void inherit(ASpec spec)
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
      inherit(base)
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

    // recurse children
    acc.each |slot| { if (slot.isAst) inherit(slot) }
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
    if (x.metaHas("maybe")) flags = flags.or(MSpecFlags.maybe)

    return flags
  }

  ** Treat 'sys' itself special using names
  private Int computeFlagsSys(ASpec x)
  {
    flags := 0
    if (x.metaHas("maybe")) flags = flags.or(MSpecFlags.maybe)
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
//    if (own.base == null) own.base = base
    return own
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Str:CSpec noSlots() { MSlots.empty.map }

  private ASpec[] stack := [,]
}