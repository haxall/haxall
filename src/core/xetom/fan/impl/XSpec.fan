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
const final class XSpec : Spec, CSpec
{
  new make(MNamespace ns, XetoSpec m)
  {
    this.ns = ns
    this.m  = m
  }

  const MNamespace ns

  const XetoSpec m

  override once Dict meta() { SpecMixer(ns, m).meta }

//////////////////////////////////////////////////////////////////////////
// Wrapped Methods
//////////////////////////////////////////////////////////////////////////

  override Lib lib() { m.lib }

  override Spec? parent() { m.parent }

  override Ref id() { m.id }

  override Str name() { m.name }

  override Str qname() { m.qname }

  override Spec type() { m.type }

  override Spec? base() { m.base }

  override Dict metaOwn() { m.metaOwn }

  override final SpecMap membersOwn() { m.membersOwn }

  override final SpecMap members() { m.members }

  override final Spec? member(Str n, Bool c := true) { m.member(n, c) }

  override Bool hasSlots() { m.hasSlots }

  override SpecMap slotsOwn() { m.slotsOwn }

  override SpecMap slots() { m.slots }

  override Spec? slot(Str n, Bool c := true) { m.slot(n, c) }

  override Spec? slotOwn(Str n, Bool c := true) { m.slotOwn(n, c) }

  override SpecMap globalsOwn() { m.globalsOwn }

  override SpecMap globals() { m.globals }

  override Bool isa(Spec x) { m.isa(x) }

  override Bool cisa(CSpec x) { m.cisa(x) }

  override FileLoc loc() { m.loc }

  override SpecBinding binding() { m.binding }

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str n) { m.get(n) }

  override Bool has(Str n) { m.has(n) }

  override Bool missing(Str n) { m.missing(n) }

  override Void each(|Obj val, Str name| f) { m.each(f) }

  override Obj? eachWhile(|Obj,Str->Obj?| f) { m.eachWhile(f) }

  override Obj? trap(Str n, Obj?[]? a := null) { m.trap(n, a) }

  override Str toStr() { m.toStr }

  override MSpecArgs args() { m.args }

  override Spec? of(Bool checked := true) { m.of(checked) }

  override Spec[]? ofs(Bool checked := true)  { m.ofs(checked) }

  override Bool isSys() { m.isSys }

  override SpecEnum enum() { m.enum }

  override CSpec? cenum(Str key, Bool checked := true) { m.cenum(key, checked) }

  override SpecFunc func() { m.func }

  override Void eachInherited(|Spec| f) { XetoUtil.eachInherited(this, f) }

  override SpecFlavor flavor() { m.flavor }
  override Bool isType()       { m.isType }
  override Bool isMixin()      { m.isMixin }
  override Bool isMeta()       { m.isMeta }
  override Bool isSlot()       { m.isSlot }

  override Bool isNone()      { m.isNone }
  override Bool isSelf()      { m.isSelf }
  override Bool isMaybe()     { m.isMaybe }
  override Bool isGlobal()    { m.isGlobal }
  override Bool isScalar()    { m.isScalar }
  override Bool isMarker()    { m.isMarker }
  override Bool isRef()       { m.isRef }
  override Bool isMultiRef()  { m.isMultiRef }
  override Bool isChoice()    { m.isChoice }
  override Bool isDict()      { m.isDict }
  override Bool isList()      { m.isList }
  override Bool isQuery()     { m.isQuery }
  override Bool isFunc()      { m.isFunc }
  override Bool isInterface() { m.isInterface }
  override Bool isComp()      { m.isComp }
  override Bool isEnum()      { m.isEnum }
  override Bool isAnd()       { m.isAnd }
  override Bool isOr()        { m.isOr }
  override Bool isCompound()  { m.isCompound }

  override Bool isAst() { false }

  override Spec asm() { this }

  override Int flags() { m.flags }

  override CSpec? cbase() { m.cbase }

  override CSpec ctype() { m.ctype }

  override CSpec? cparent() { m.cparent }

  override Dict cmeta() { m.cmeta }

  override Bool cmetaHas(Str name) { m.cmetaHas(name) }

  override CSpec? cmember(Str n, Bool c := true) { m.cmember(n, c) }

  override Void cslots(|CSpec, Str| f) { m.cslots(f) }

  override Obj? cslotsWhile(|CSpec, Str->Obj?| f) { m.cslotsWhile(f) }

  override XetoSpec? cof()  { m.cof }

  override XetoSpec[]? cofs()  { m.cofs }

  override Type fantomType() { m.fantomType }

  override Int inheritanceDigest() { m.inheritanceDigest }
}

