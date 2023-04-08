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

    // special handling for sys::Obj
    if (isObj(spec)) { spec.cslotsRef = noSlots; return }

    // infer type if unspecified or process subtype;
    // this method returns the spec to use for the base
    spec.base = inferType(spec, spec.base ?: spec.type)

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
    autoCount := 0
    if (!isSys && base === env.sys.and)
    {
      ofs := spec.cofs
      if (ofs != null) ofs.each |x|
      {
if (x.isAst)
{
  inheritSpec(x)
}
        x.cslots.each |slot|
        {
          // TODO: need to handle conflicts in compiler checks
          name := slot.name
          if (XetoUtil.isAutoName(name)) name = "_" + (autoCount++)
          dup := acc[name]
          if (dup != null && dup !== slot)
          {
            if (slot.isAst)
              acc[name] = overrideSlot(dup, slot)
            else
              throw Err("TODO")
          }
          else
          {
            acc[name] = slot
          }
        }
      }
    }
    else
    {
      base.cslots.each |slot|
      {
        acc[slot.name] = slot
      }
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
// Infer Type
//////////////////////////////////////////////////////////////////////////

  CSpec inferType(AObj x, CSpec? base)
  {
    // if source didn't specify the type, then we infer we must infer type
    if (x.typeRef == null)
    {
      // infer type from base, or if not specified then
      // scalars default to str and everything else to dict
      if (base != null)
        x.typeRef = ARef(x.loc, base.ctype)
      else
        x.typeRef = x.val == null ? sys.dict : sys.str
    }

    // we have an explicit type
    else
    {
      // if base is maybe and my own type is not then clear maybe flag
      if (x.isSpec && base.isMaybe && !metaHas(x, "maybe"))
        metaAddNone(x, "maybe")
    }

    // return the spec to use for the base
    return base ?: x.type
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

  private ASpec overrideSlot(CSpec base, ASpec slot)
  {
    // infer type from base
    inferType(slot, base)

    return slot
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  private Void inheritMeta(ASpec spec)
  {
    if (spec.meta == null) return
    inheritVal(spec.meta, null)
  }

  private Void inheritVal(AVal x, ASpec? base)
  {
    // infer type if unspecified
    inferType(x, base)

    // recurse
    if (x.slots != null) x.slots.each |kid| { inheritVal(kid, null) }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Str:CSpec noSlots() { MSlots.empty.map }

  private ASpec[] stack := [,]
}