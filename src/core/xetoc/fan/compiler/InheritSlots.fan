//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//    6 Apr 2023  Brian Frank  Redesign from proto
//

using util
using xeto
using xetom
using haystack

**
** InheritSlots walks all the top-level specs and nested slots. When complete
** the following fields must be set on each ASpec:
**   - members
**   - slots
**
** Nested slots also have the following set in this step (tops set these
** fields in InheritBase):
**   - base
**   - typeRef
**   - flags
**
@Js
internal class InheritSlots : InheritFlags
{
  override Void run()
  {
    lib.ast.topsInInheritOrder.each |spec| { inherit(spec) }
    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  ** Process inheritance of given spec with cyclic checks
  private Void inherit(ASpec spec)
  {
    // skip if already inherited
    if (spec.ast.members != null) return

    // InheritBase finalized base/typeRef/flags for tops (flags >= 0);
    // nested slots are finalized here because their base is an output
    // of the parent's override resolution
    if (spec.flags < 0)
    {
      // infer the base we inherit from (may be null)
      spec.ast.base = inferBase(spec)

      // now infer the type of the spec
      explicitTypeRef := spec.typeRef != null
      if (!explicitTypeRef) spec.typeRef = inferType(spec)

      // if we couldn't infer base before, then use type as base
      if (spec.base == null) spec.ast.base = spec.typeRef.deref

      // if base is maybe and my own type is not then clear maybe flag
      if (explicitTypeRef && spec.base.isMaybe && !spec.metaHas("maybe"))
        spec.metaSetNone("maybe")

      // compute effective flags
      inheritFlags(spec)
    }

    // compute effective slots
    inheritSlots(spec)

    // recurse children
    if (spec.declared != null) spec.declared.each |slot| { inherit(slot) }
  }

//////////////////////////////////////////////////////////////////////////
// Infer Base
//////////////////////////////////////////////////////////////////////////

  ** Infer the base spec we inherit from
  Spec? inferBase(ASpec x)
  {
    // if already inferred
    if (x.base != null) return x.base

    // try to infer from the explicit type if available
    return x.typeRef?.deref
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
    if (x.typeRef != null) return x.typeRef

    // infer type from base
    if (x.base != null) return ASpecRef(x.loc, x.base.type)

    // items of a MultiRef list are always refs
    if (x.parent != null && x.parent.isMultiRef) return x.typeRef = sys.ref

    // scalars default to str and everything else to dict
    x.typeRef = x.val == null ? sys.dict : sys.str
    return x.typeRef
  }

//////////////////////////////////////////////////////////////////////////
// Slots
//////////////////////////////////////////////////////////////////////////

  ** The compute the effective slots and store in members/slots
  private Void inheritSlots(ASpec spec)
  {
    autoCount := 0
    slots     := Str:Spec[:] { ordered = true }
    globals   := Str:Spec[:] { ordered = true }
    SpecMap? baseGlobals := null

    // first inherit slots from base type
    if (spec.isAnd)
    {
      ofs := spec.ofs(false)
      if (ofs != null) ofs.each |of|
      {
        if (of.isAst) inherit(of)
        autoCount = inheritSlotsFrom(spec, slots, globals, autoCount, of)
      }
    }
    else
    {
      from := spec.base
      if (spec.isCovariantOverride) from = spec.type
      if (from.isAst) inherit(from)
      if (!from.isAst) baseGlobals = from.globals
      autoCount = inheritSlotsFrom(spec, slots, globals, autoCount, from)
    }

    // now merge in my own slots
    addOwnSlots(spec, slots, globals, autoCount)

    // slots map
    slotsMap := SpecMap(slots)

    // globals map - optimize to reuse globals from base for common case
    SpecMap? globalsMap
    if (baseGlobals != null && !spec.ast.declaredHasGlobals)
      globalsMap = baseGlobals
    else
      globalsMap = SpecMap(globals)

    // we now have effective members
    spec.ast.slots   = slotsMap
    spec.ast.members = SpecMap(slotsMap, globalsMap)
  }

  ** Inherit slots from the given base type to accumulator
  private Int inheritSlotsFrom(ASpec spec, Str:Spec slots, Str:Spec globals, Int autoCount, Spec base)
  {
    base.members.each |member|
    {
      // we don't inherit constructors
      if (spec.isInterface && metaHas(member, "new")) return

      // re-autoname to cleanly inherit from multiple types
      name := member.name
      if (XetoUtil.isAutoName(name)) name = compiler.autoName(autoCount++)

      // mixins only inherit slots they override
      if (spec.isMixin && spec.declared?.get(name) == null) return

      // check for duplicate
      dup := slots[name] ?: globals[name]

      // if its the exact same member, all is ok
      if (dup === member) return

      // otherwise we have conflict
      if (dup != null) member = mergeInheritedSlots(spec, name, dup, member)

      // accumlate
      if (member.isSlot)
        slots[name] = member
      else
        globals[name] = member
    }

    return autoCount
  }

  ** Merge in my own slots to accumulator and handle slot overrides
  private Int addOwnSlots(ASpec spec,  Str:Spec slots, Str:Spec globals, Int autoCount)
  {
    if (spec.declared == null) return autoCount
    spec.declared.each |ASpec slot|
    {
      // check autonaming
      name := slot.name
      if (XetoUtil.isAutoName(name)) name = compiler.autoName(autoCount++)

      // if duplicate then check if validate override
      dup := slots[name] ?: globals[name]
      if (dup != null)
      {
        if (dup === slot) return
        slot = overrideSlot(dup, slot)
      }
      else if (slot.typeRef == null && slot.isSlot)
      {
        // untyped slot with no inherited member may bind to a global
        // contributed by a depend lib mixin for my type chain
        g := depends.slotx(spec.base, name)
        if (g != null) slot = overrideSlot(g, slot)
      }

      // accumlate
      if (slot.isSlot)
        slots[name] = slot
      else
        globals[name] = slot
    }
    return autoCount
  }

  ** Override the base slot from an inherited type
  private ASpec overrideSlot(Spec base, ASpec slot)
  {
    if (slot.isInterfaceSlot)
    {
      // interfaces don't override constructor and static slots
      if (metaHas(base, "new")) return slot
      if (metaHas(base, "static")) return slot
    }

    if (slot.isGlobal) err("Duplicate global: $base", slot.loc)

    slot.ast.base = base

    val := slot.val
    if (val != null && val.typeRef == null)
      val.typeRef = ASpecRef(val.loc, base.type)

    return slot
  }

  ** Handle inheriting the same slot name from two different super types
  private Spec mergeInheritedSlots(ASpec spec, Str name, Spec a, Spec b)
  {
    // if both are queries, then we need to merge the slots
    if (a.isQuery && b.isQuery) return mergeQuerySlots(spec, name, a, b)

    // check if b is derived from a in which case we use b (and vise versa)
    if (isDerivedFrom(a, b)) return b
    if (isDerivedFrom(b, a)) return a

    // if both slots are unchanged references to the same global, then
    // we can cleanly inherit without conflict; keep the first slot since
    // both are structurally identical refs to the same global (its own
    // base still chains to that global)
    if (a.base === b.base && isUnchangedGlobalRef(a) && isUnchangedGlobalRef(b))
      return a

    // no resolution
    err("Conflicing inherited slots: $a.qname, $b.qname", spec.loc)
    return a
  }

  ** Is the given slot just an unchanged reference to a global; that is its
  ** base is a global and it has not added new meta nor a covariant type
  ** override.  Slot may be an AST spec from this lib or an assembled spec
  ** inherited from a dependency.
  private Bool isUnchangedGlobalRef(Spec slot)
  {
    base := slot.base
    if (base == null || !base.isGlobal) return false

    // covariant type override
    if (XetoUtil.isCovariantOverride(slot)) return false

    // no own meta; AST specs haven't reified metaOwn yet at this step
    // so check the raw declared meta, otherwise use assembled metaOwn
    ast := slot as ASpec
    if (ast != null) return ast.ast.meta == null || ast.ast.meta.size == 0
    return slot.metaOwn.isEmpty
  }

  ** Is b derived from a through its base inheritance chain
  private Bool isDerivedFrom(Spec a, Spec? b)
  {
    if (b == null) return false
    if (b === a) return true
    return isDerivedFrom(a, b.base)
  }

  private Spec mergeQuerySlots(ASpec spec, Str name, Spec a, Spec b)
  {
    // a query can only be merged if both sides refine a single original query
    // definition in the inheritance tree (e.g. both refine "ph::Equip.points").
    // two independent queries with the same slot name are not the same query
    // even if their meta matches, so they cannot be unioned
    if (queryOrigin(a) !== queryOrigin(b))
    {
      err("Cannot merge unrelated query slots '$name': $a.qname and $b.qname", spec.loc)
      return a
    }

    // the merged query is a single declared slot that unions the constraints
    // of all the supertype queries, followed by the spec's own declared query
    // constraints if it has one (e.g. "A & B { points: { ... } }").  with three
    // or more supertypes the slots are merged pairwise - "merge(merge(A, B), C)"
    // - so on the second and later pass "a" is the merge slot we already built
    // (it lives in the spec's declared map) and we just union in the next
    // supertype "b"; the own constraints are re-ordered to stay last each pass.
    loc := spec.loc
    cur := spec.declared?.get(name)
    extending := a === cur
    merge := extending ? (ASpec)a : (cur ?: ASpec(loc, lib, spec, name))
    if (!extending)
    {
      // finalize type/base/flags now (even when reusing the spec's own slot):
      // we set members below which short-circuits the slot's own later inherit
      // pass, so these would otherwise never get computed.  skipped when
      // extending since "a" is the merge itself (base would self-cycle)
      merge.typeRef = ASpecRef(loc, a.type)
      merge.ast.base = a
      merge.flags = a.flags
    }

    // union the constraints of both supertype queries, then fold the merge's
    // own declared constraints last so they always order after the supertypes
    // (even when extending pairwise for 3+ types).  the merge's own constraints
    // are parented to the merge, so we skip them while accumulating supertypes
    // and add them from its declared slots afterwards
    acc := Str:Spec[:] { ordered = true }
    autoCount := 0
    autoCount = mergeQueryConstraints(merge, acc, autoCount, a.slots.list, false)
    autoCount = mergeQueryConstraints(merge, acc, autoCount, b.slots.list, false)
    autoCount = mergeQueryConstraints(merge, acc, autoCount, cur?.declared?.vals, true)

    specMap := SpecMap(acc)
    merge.ast.members = specMap
    merge.ast.slots   = specMap

    // the merge is a declared slot of the spec (reusing the own slot if any)
    spec.initDeclared[name] = merge
    return merge
  }

  ** Union one query's constraints into the merged accumulator.  Constraints
  ** may be auto-named (re-numbered to stay unique) or explicitly named (which
  ** cannot reuse a name already in the accumulator).  When `own` is true the
  ** constraints are the merge's own declared slots: they are processed now
  ** (their inherit pass won't recurse them since the merge's members are
  ** already finalized).  When false they are inherited from a supertype query,
  ** and any already parented to the merge are its own constraints (added last
  ** via the `own` pass) so we skip them here.
  private Int mergeQueryConstraints(ASpec merge, Str:Spec acc, Int autoCount, Spec[]? slots, Bool own)
  {
    slots?.each |slot|
    {
      if (own) inherit(slot)  // own constraints are this lib's ASpecs
      else if (slot.parent === merge) return  // own constraint, folded in last
      name := slot.name
      if (XetoUtil.isAutoName(name))
        name = compiler.autoName(autoCount++)
      else if (acc[name] != null)
        err("Duplicate query slot '$name'", slot.loc)
      acc[name] = slot
    }
    return autoCount
  }

  ** The original query definition a query slot refines: walk the base chain to
  ** the slot whose base is the bare query type rather than another query slot
  ** (e.g. "ph::Equip.points", whose base is "sys::Query").  Two queries can only
  ** be merged if they share the same origin.
  private Spec queryOrigin(Spec q)
  {
    while (q.base != null && q.base.isQuery && q.base.isSlot) q = q.base
    return q
  }

}

