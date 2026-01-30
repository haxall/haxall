//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Nov 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** Implementation of extended spec that lazily merges in all mixins
**
@Js
const final class XSpec : WrapSpec
{
  new make(XetoSpec m, Spec[] mixins) : super(m) { this.mixins = mixins }

  const Spec[] mixins

//////////////////////////////////////////////////////////////////////////
// Meta
//////////////////////////////////////////////////////////////////////////

  override once Dict meta()
  {
    acc := Etc.dictToMap(m.meta)
    mixins.each |x| { metaMerge(acc, x.meta) }
    return Etc.dictFromMap(acc)
  }

  private Void metaMerge(Str:Obj acc, Dict meta)
  {
    if (meta.isEmpty) return
    meta.each |v, n|
    {
      if (n == "mixin") return
      if (acc[n] == null) acc[n] = v
    }
  }

//////////////////////////////////////////////////////////////////////////
// Members
//////////////////////////////////////////////////////////////////////////

  override SpecMap membersOwn() { SpecMap(slotsOwn, globalsOwn) }

  override SpecMap members() { SpecMap(slots, globals) }

//////////////////////////////////////////////////////////////////////////
// Slots
//////////////////////////////////////////////////////////////////////////

  override once SpecMap slotsOwn()
  {
    acc := Str:Spec[:]
    acc.ordered = true
    m.slotsOwn.each |s, n| { acc[n] = slot(n) }
    return SpecMap(acc)
  }

  override once SpecMap slots()
  {
    collisions := false
    acc := Str:Obj[:]
    acc.ordered = true

    // start of with the effective slots
    m.slots.each |slot, name|
    {
      acc[name] = slotx(slot)
    }

    // merge in mixin new slots
    mixins.each |mix|
    {
      mix.slots.each |slot, name|
      {
        dup := acc[name]

        // if no dup, then accumulate it
        if (dup ==  null) { acc[name] = slot; return }

        // ignore if same one we already mapped
        if (dup === slot) return

        // if slotx from original we already processed it
        // slot already processed
        if (dup is XSlotSpec) return

        // otherwise a duplicate is a naming collision
        if (dup is List)
          ((List)dup).add(slot)
        else
          acc[name] = Spec[dup, slot]
        collisions = true
      }
    }

    return collisions ? SpecMap.makeCollisions(acc) : SpecMap(acc)
  }

  private Spec slotx(Spec orig)
  {
    [Str:Obj]? acc := null
    mixins.each |m|
    {
      mslot := m.slotOwn(orig.name, false)
      if (mslot == null) return
      if (acc == null) acc = Etc.dictToMap(orig.meta)
      metaMerge(acc, mslot.metaOwn)
    }
    if (acc == null) return orig
    return XSlotSpec(orig, Etc.dictFromMap(acc))
  }

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  override once SpecEnum enum()
  {
    if (!isEnum) throw UnsupportedErr("Spec is not enum: $qname")
    return MEnum.init(slots)
  }
}

**************************************************************************
** XSlotSpec
**************************************************************************

@Js
const class XSlotSpec: WrapSpec
{
  new make(XetoSpec m, Dict meta) : super(m) { this.meta = meta }

  const override Dict meta
}

**************************************************************************
** WrapSpec
**************************************************************************

@Js
const class WrapSpec : Spec
{
  new make(XetoSpec m) { this.m = m }

  const XetoSpec m

  override Lib lib() { m.lib }

  override Spec? parent() { m.parent }

  override Ref id() { m.id }

  override Str name() { m.name }

  override Str qname() { m.qname }

  override Spec type() { m.type }

  override Spec? base() { m.base }

  override Dict metaOwn() { m.metaOwn }

  override Dict meta() { m.meta }

  override SpecMap membersOwn() { m.membersOwn }

  override SpecMap members() { m.members }

  override final Spec? member(Str n, Bool c := true) { members.get(n, c) }

  override final Spec? slot(Str n, Bool c := true) { slots.get(n, c) }

  override final Spec? slotOwn(Str n, Bool c := true) { slotsOwn.get(n, c) }

  override SpecMap slotsOwn() { m.slotsOwn }

  override SpecMap slots() { m.slots }

  override final SpecMap globalsOwn() { m.globalsOwn }

  override final SpecMap globals() { m.globals }

  override final Bool isa(Spec x) { m.isa(x) }

  override final FileLoc loc() { m.loc }

  override final SpecBinding binding() { m.binding }

  override final Bool isEmpty() { false }

  @Operator override Obj? get(Str name) { XetoUtil.specGet(this, name) }

  override Bool has(Str name) { XetoUtil.specHas(this, name) }

  override Bool missing(Str name) { XetoUtil.specMissing(this, name) }

  override Void each(|Obj val, Str name| f) { XetoUtil.specEach(this, f) }

  override Obj? eachWhile(|Obj val, Str name->Obj?| f) { XetoUtil.specEachWhile(this, f) }

  override Obj? trap(Str name, Obj?[]? args := null) { XetoUtil.specTrap(this, name, args) }

  override final Str toStr() { m.toStr }

  override final Spec? of(Bool checked := true) { m.of(checked) }

  override final Spec[]? ofs(Bool checked := true)  { m.ofs(checked) }

  override SpecEnum enum() { m.enum }

  override final SpecFunc func() { m.func }

  override final Void eachInherited(|Spec| f) { XetoUtil.eachInherited(this, f) }

  override final SpecFlavor flavor() { m.flavor }
  override final Bool isType()       { m.isType }
  override final Bool isMixin()      { m.isMixin }
  override final Bool isMember()     { m.isMember }
  override final Bool isSlot()       { m.isSlot }
  override final Bool isGlobal()     { m.isGlobal }

  override final Bool isNone()      { m.isNone }
  override final Bool isSelf()      { m.isSelf }
  override final Bool isMaybe()     { m.isMaybe }
  override final Bool isScalar()    { m.isScalar }
  override final Bool isMarker()    { m.isMarker }
  override final Bool isRef()       { m.isRef }
  override final Bool isMultiRef()  { m.isMultiRef }
  override final Bool isChoice()    { m.isChoice }
  override final Bool isDict()      { m.isDict }
  override final Bool isList()      { m.isList }
  override final Bool isGrid()      { m.isGrid }
  override final Bool isQuery()     { m.isQuery }
  override final Bool isFunc()      { m.isFunc }
  override final Bool isInterface() { m.isInterface }
  override final Bool isComp()      { m.isComp }
  override final Bool isEnum()      { m.isEnum }
  override final Bool isAnd()       { m.isAnd }
  override final Bool isOr()        { m.isOr }
  override final Bool isSys()       { m.isSys }
  override final Bool isHaystack()  { m.isHaystack }
  override final Bool isCompound()  { m.isCompound }
  override final Bool isTransient() { m.isTransient }

  override final Int flags() { m.flags }

  override final Bool isAst() { false }
  override final Spec asm()  { this }

  override final Type fantomType() { m.fantomType }

  override final Int inheritanceDigest() { m.inheritanceDigest }

}

