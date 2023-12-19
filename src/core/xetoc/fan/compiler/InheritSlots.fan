//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//    6 Apr 2023  Brian Frank  Redesign from proto
//

using util
using xetoEnv

**
** InheritSlots walks all the specs:
**   - infer type if unspecified
**   - resolves base
**   - handles slot overrides
**   - computes spec flags
**   - special handling for enums
**
** When this step completes, the following fields must be set on each ASpec:
**   - base
**   - typeRef
**   - flags
**   - cslotsRef
**
internal class InheritSlots : Step
{
  override Void run()
  {
    lib.tops.each |spec| { inherit(spec) }
    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  ** Process inheritance of given spec with cyclic checks
  private Void inherit(ASpec spec)
  {
    // check if already inherited
    if (spec.cslotsRef != null) return

    // check for cyclic inheritance
    if (stack.containsSame(spec) && !isSys)
    {
      err("Cyclic inheritance: $spec.name", spec.loc)
      spec.cslotsRef = noSlots
    }

    // push onto stack to keep track of cycles
    stack.push(spec)

    // process
    doInherit(spec)

    // pop from stack
    stack.pop
  }

  private Void doInherit(ASpec spec)
  {
    // special handling for sys::Obj
    if (spec.isObj) { spec.cslotsRef = noSlots; return }

    // infer the base we inherit from (may be null)
    spec.base = inferBase(spec)

    // now infer the type of the spec
    spec.typeRef = inferType(spec)

    // if we couldn't infer base before, then use type as base
    if (spec.base == null) spec.base = spec.type

    // if base is in my AST, then recursively process it first
    if (spec.base.isAst) inherit(spec.base)

    // special handling for Enums
    if (isEnum(spec)) return inheritEnum(spec)

    // compute effective flags
    inheritFlags(spec)

    // compute effective slots
    inheritSlots(spec)

    // recurse children
    if (spec.slots != null) spec.slots.each |slot| { inherit(slot) }
  }

//////////////////////////////////////////////////////////////////////////
// Infer Base
//////////////////////////////////////////////////////////////////////////

  ** Infer the base spec we inherit from
  CSpec? inferBase(ASpec x)
  {
    // if already inferred
    if (x.base != null) return x.base

    // first try to inherit from parent spec's inherited slot
    /* TODO
    base := inferBaseInherited(x)
    if (base != null) return base
    */

    // infer base from global slot
    base := inferBaseGlobal(x)
    if (base != null) return base

    // try to infer from the explicit type if available
    return x.type
  }

  ** Attempt to infer base from parent type's inherited slots
  ** NOTE: this code gets used in deeply nested specs
  /* TODO
  private CSpec? inferBaseInherited(ASpec x)
  {
    if (x.parent?.ctype != null)
    {
      p := x.parent.ctype.cslot(x.name, false)
      if (p != null) return p
    }
    return null
  }
  */

  ** Attempt to infer base from global slots
  private CSpec? inferBaseGlobal(ASpec x)
  {
    // don't process top-level types/globals
    if (x.isTop) return null

    // don't process constrained query slots
    if (x.parent.isQuery) return null

     // check for global slot with this name
     return ns.resolveGlobal(x.name, x.loc)
  }

//////////////////////////////////////////////////////////////////////////
// Infer Type
//////////////////////////////////////////////////////////////////////////

  ** If x does not have an explicit type specified, then infer
  ** it from either given base or whether it is a scalar/dict.
  ** If a type is given, then we use that to decide if we need
  ** clear maybe flag (set to None).
  ASpecRef inferType(ASpec x)
  {
    // if already specified use it
    if (x.typeRef != null)
    {
      // if base is maybe and my own type is not then clear maybe flag
      if (x.base != null && x.base.isMaybe && !x.metaHas("maybe"))
        x.metaSetNone("maybe")

      return x.typeRef
    }

    // infer type from base
    if (x.base != null) return ASpecRef(x.loc, x.base.ctype)

    // scalars default to str and everything else to dict
    return x.typeRef = x.val == null ? sys.dict : sys.str
  }

//////////////////////////////////////////////////////////////////////////
// Flags
//////////////////////////////////////////////////////////////////////////

  ** Compute the effective flags which is bitmask used for
  ** fast access of key types in my inheritance hiearchy
  private Void inheritFlags(ASpec x)
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
      maybe := x.meta.get("maybe")
      if (maybe != null)
      {
        if (maybe.isNone)
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
// Slots
//////////////////////////////////////////////////////////////////////////

  ** The compute the effective slots and store in cslotsRef
  private Void inheritSlots(ASpec spec)
  {
    acc := Str:CSpec[:]
    acc.ordered = true
    autoCount := 0
    base := spec.base

    // first inherit slots from base type
    if (!isSys && base === env.sys.and)
    {
      ofs := spec.cofs
      if (ofs != null) ofs.each |of|
      {
        if (of.isAst) inherit(of)
        autoCount = inheritSlotsFrom(spec, acc, autoCount, of)
      }
    }
    else
    {
      autoCount = inheritSlotsFrom(spec, acc, autoCount, base)
    }

    // now merge in my own slots
    addOwnSlots(spec, acc, autoCount)

    // we now have effective slot map
    spec.cslotsRef = acc
  }

  ** Inherit slots from the given base type to accumulator
  private Int inheritSlotsFrom(ASpec spec, Str:CSpec acc, Int autoCount, CSpec base)
  {
    base.cslots |slot|
    {
      // re-autoname to cleanly inherit from multiple types
      name := slot.name
      if (XetoUtil.isAutoName(name)) name = compiler.autoName(autoCount++)

      // check for duplicate
      dup := acc[name]

      // if its the exact same slot, all is ok
      if (dup === slot) return

      // otherwise we have conflict
      if (dup != null) slot = mergeInheritedSlots(spec, name, dup, slot)

      // accumlate
      acc[name] = slot
    }

    return autoCount
  }

  ** Merge in my own slots to accumulator and handle slot overrides
  private Int addOwnSlots(ASpec spec, Str:CSpec acc, Int autoCount)
  {
    if (spec.slots == null) return autoCount
    spec.slots.each |ASpec slot|
    {
      name := slot.name
      if (XetoUtil.isAutoName(name)) name = compiler.autoName(autoCount++)

      dup := acc[name]
      if (dup != null)
      {
        if (dup === slot) return
        acc[name] = overrideSlot(dup, slot)
      }
      else
      {
        acc[name] = slot
      }
    }
    return autoCount
  }

  ** Override the base slot from an inherited type
  private ASpec overrideSlot(CSpec base, ASpec slot)
  {
    slot.base = base

    val := slot.val
    if (val != null && val.typeRef == null)
      val.typeRef = ASpecRef(val.loc, base.ctype)

    return slot
  }

  ** Handle inheriting the same slot name from two different super types
  private CSpec mergeInheritedSlots(ASpec spec, Str name, CSpec a, CSpec b)
  {
    // if both are queries, then we need to merge the slots
    if (a.isQuery && b.isQuery) return mergeQuerySlots(spec, name, a, b)

    // check if b is derived from a in which case we use b (and vise versa)
    if (isDerivedFrom(a, b)) return b
    if (isDerivedFrom(b, a)) return a

    // no resolution
    err("Conflicing inherited slots: $a.qname, $b.qname", spec.loc)
    return a
  }

  ** Is b derived from a through its base inheritance chain
  private Bool isDerivedFrom(CSpec a, CSpec? b)
  {
    if (b == null) return false
    if (b === a) return true
    return isDerivedFrom(a, b.cbase)
  }

  private CSpec mergeQuerySlots(ASpec spec, Str name, CSpec a, CSpec b)
  {
    // TODO: we need a lot of checking to verify a and b derive from same query

    // create new merged slot
    loc := spec.loc
    ASpec merge := ASpec(loc, lib, spec, name)
    merge.typeRef = ASpecRef(loc, a.ctype)
    merge.base = a
    merge.flags = a.flags

    // merge in slots from both a and b
    acc := Str:CSpec[:]
    acc.ordered = true
    autoCount := 0
    autoCount = inheritSlotsFrom(merge, acc, autoCount, a)
    autoCount = inheritSlotsFrom(merge, acc, autoCount, b)
    merge.cslotsRef = acc

    // we need to make this a new declared slot
    spec.initSlots.add(name, merge)

    return merge
  }

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  ** At this point the ASpec.type will be sys::Enum (base is still null)
  private Bool isEnum(ASpec spec)
  {
    spec.type != null && spec.type.isSys && spec.type.name == "Enum"
  }

  ** Enum slots are implied as the parent type
  private Void inheritEnum(ASpec spec)
  {
    // set base to type (which is sys::Enum)
    spec.base = spec.type

    // set flags to sys::Enum's flags
    spec.flags = spec.base.flags

    // sealed is implied
    loc := spec.loc
    if (spec.metaHas("sealed"))
      err("Enum types are implied sealed", loc)
    else
      spec.metaInit.set("sealed", markerScalar(loc))

    // recurse children slots to process as the enum items
    slots := Str:CSpec[:]; slots.ordered = true
    enums := Str:CSpec[:]; enums.ordered = true
    hasKeys := false
    enumRef := ASpecRef(loc, spec)
    spec.slots.each |slot|
    {
      item := inheritEnumItem(spec, enumRef, slot)

      // map slot by its programatic name
      slots.add(item.name, item)

      // map by key
      key := item.name
      keyVal := item.metaGet("key") as AScalar
      if (keyVal != null)
      {
        key = keyVal.str
        hasKeys = true
      }
      if (enums[key] != null)
        err("Duplicate enum key: $key", item.loc)
      else
        enums.add(key, item)
    }

    // if we don't have any key meta, then reuse same slots map to save RAM
    if (!hasKeys) enums = slots

    // save away both slots and enums
    spec.cslotsRef = slots
    spec.enums = enums
  }

  ** Check that an item was a marker only, then coerce to be derived from parent enum
  private ASpec inheritEnumItem(ASpec enum, ASpecRef enumRef, ASpec item)
  {
    // this should only be true if slot created in Parser.parseMarkerSpec
    if (item.typeRef !== sys.marker)
      err("Enum item '$item.name' cannot have type", item.loc)

    item.base      = enum
    item.typeRef   = enumRef
    item.flags     = enum.flags
    item.cslotsRef = noSlots
    return item
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  const Str:CSpec noSlots := Str:CSpec[:]

  private ASpec[] stack := [,]
  private Str:CSpec? globals := [:]
}