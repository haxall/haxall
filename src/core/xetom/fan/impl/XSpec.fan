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
    mixins.each |m|
    {
      m.slots.each |slot, name|
      {
        dup := acc[name]
        if (dup != null)
        {
          list := dup as Spec[] ?: Spec[dup]
          list.add(slot)
          collisions = true
        }
        else
        {
          acc[name] = slot
        }
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

  @Operator override final Obj? get(Str n) { m.get(n) }

  override final Bool has(Str n) { m.has(n) }

  override final Bool missing(Str n) { m.missing(n) }

  override final Void each(|Obj val, Str name| f) { m.each(f) }

  override final Obj? eachWhile(|Obj,Str->Obj?| f) { m.eachWhile(f) }

  override final Obj? trap(Str n, Obj?[]? a := null) { m.trap(n, a) }

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
  override final Bool isQuery()     { m.isQuery }
  override final Bool isFunc()      { m.isFunc }
  override final Bool isInterface() { m.isInterface }
  override final Bool isComp()      { m.isComp }
  override final Bool isEnum()      { m.isEnum }
  override final Bool isAnd()       { m.isAnd }
  override final Bool isOr()        { m.isOr }
  override final Bool isSys()       { m.isSys }
  override final Bool isCompound()  { m.isCompound }

  override final Int flags() { m.flags }

  override final Bool isAst() { false }
  override final Spec asm()  { this }

  override final Type fantomType() { m.fantomType }

  override final Int inheritanceDigest() { m.inheritanceDigest }

  /* CSpec
  override final Bool hasSlots() { !m.slots.isEmpty }

  override final CSpec? cenum(Str key, Bool checked := true) { m.cenum(key, checked) }

  override final Bool isSys() { m.isSys }

  override final Bool isAst() { false }

  override final Bool cisa(CSpec x) { m.cisa(x) }

  override final Spec asm() { this }

  override final MSpecArgs args() { m.args }

  override final Int flags() { m.flags }

  override final CSpec? cbase() { m.cbase }

  override final CSpec ctype() { m.ctype }

  override final CSpec? cparent() { m.cparent }

  override final Dict cmeta() { m.cmeta }

  override final Bool cmetaHas(Str name) { m.cmetaHas(name) }

  override final CSpec? cmember(Str n, Bool c := true) { m.cmember(n, c) }

  override final Void cmembers(|CSpec, Str| f) { m.cmembers(f) }

  override final Void cslots(|CSpec, Str| f) { m.cslots(f) }

  override final Obj? cslotsWhile(|CSpec, Str->Obj?| f) { m.cslotsWhile(f) }

  override final XetoSpec? cof()  { m.cof }

  override final XetoSpec[]? cofs()  { m.cofs }
  */

}

