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
    if (isData) return
    inherit(lib)
    bombIfErr
  }

  private Void inherit(ASpec spec)
  {
    // check if already inherited
    if (spec.cslotsRef != null) return

    // if base type reference is null, then infer it
    if (spec.base == null)
    {
      // infer the base
      spec.base = inferBase(spec)

      // if base is still null this is sys::Obj
      if (spec.base == null) { spec.cslotsRef = noSlots; return }
    }

    // if base is spec, then recursively inherit it first
    base := spec.base.creferent
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
// Infer Base
//////////////////////////////////////////////////////////////////////////

  private ARef? inferBase(ASpec x)
  {
    // types without a supertype are assumed to be sys::Dict
    if (x.isType)
    {
      if (x.qname == "sys::Obj") return null
      return sys.dict
    }

    // TODO: total hack until we get inheritance
    if (x.name == "points")
      return sys.query

    // TODO: fallback to Str/Dict
    if (x.val != null)
      return sys.str
    else
      return sys.dict
  }

//////////////////////////////////////////////////////////////////////////
// Override
//////////////////////////////////////////////////////////////////////////

  private ASpec overrideSlot(CSpec base, ASpec own)
  {
// TODO
//    if (own.base == null) own.base = ARef(own.loc, base)
    return own
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Str:CSpec noSlots() { MSlots.empty.map }

  private ASpec[] stack := [,]
}