//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
//using haystack

**
** Implementation of Spec wrapped by XetoSpec
**
@Js
const class MSpec
{
  new make(MSpecInit init)
  {
    this.loc        = init.loc
    this.name       = init.name
    this.parent     = init.parent
    this.base       = init.base
    this.type       = init.type
    this.meta       = init.meta
    this.metaOwn    = init.metaOwn
    this.slots      = init.slots
    this.slotsOwn   = init.slotsOwn
    this.globalsOwn = init.globalsOwn
    this.flags      = init.flags
    this.args       = init.args
  }

  virtual XetoLib lib() { parent.lib }

  const FileLoc loc

  const Str name

  const XetoSpec? parent

  virtual Ref id() { Ref(qname) }

  virtual Str qname() { parent.qname + "." + name }

  const XetoSpec type

  const XetoSpec? base

  const Dict meta

  const Dict metaOwn

  const SpecMap slots

  const SpecMap slotsOwn

  const SpecMap globalsOwn

  Bool hasSlots() { !slots.isEmpty }

  XetoSpec? slot(Str name, Bool checked := true) { slots.get(name, checked) }

  XetoSpec? slotOwn(Str name, Bool checked := true) { slotsOwn.get(name, checked) }

  const MSpecArgs args

  override Str toStr() { qname }

  virtual SpecBinding binding() { type.binding }

  virtual MEnum enum() { throw UnsupportedErr("Spec is not enum: $qname") }

  MFunc func(Spec spec)
  {
    if (funcRef != null) return funcRef
    if (!hasFlag(MSpecFlags.func)) throw UnsupportedErr("Spec is not func: $qname")
    // must be ok if dups by multiple threads
    MSpec#funcRef->setConst(this, MFunc.init(spec))
    return funcRef
  }
  private const MFunc? funcRef

  virtual Int inheritanceDigest(Spec spec)
  {
    throw UnsupportedErr(qname)
  }

//////////////////////////////////////////////////////////////////////////
// Dict Representation
//////////////////////////////////////////////////////////////////////////

  const static Ref specSpecRef := Ref("sys::Spec")

  Obj? get(Str name)
  {
    if (name == "id")   return id
    if (name == "name") return this.name
    if (name == "spec") return specSpecRef
    if (isType)
    {
      if (name == "base") return base?.id
    }
    else
    {
      if (name == "type") return type.id
    }
    return meta.get(name)
  }

  Bool has(Str name)
  {
    if (name == "id")   return true
    if (name == "name") return true
    if (name == "spec") return true
    if (name == "base") return isType && base != null
    if (name == "type") return !isType
    return meta.has(name)
  }

  Bool missing(Str name)
  {
    if (name == "id")   return false
    if (name == "name") return false
    if (name == "spec") return false
    if (name == "base") return !isType || base == null
    if (name == "type") return isType
    return meta.missing(name)
  }

  Void each(|Obj val, Str name| f)
  {
    f(id, "id")
    f(name, "name")
    f(specSpecRef, "spec")
    if (isType)
    {
      if (base != null) f(base.id, "base")
    }
    else
    {
      f(type.id, "type")
    }
    meta.each(f)
  }

  Obj? eachWhile(|Obj val, Str name->Obj?| f)
  {
    r := f(id, "id");            if (r != null) return r
    r  = f(name, "name");        if (r != null) return r
    r  = f(specSpecRef, "spec"); if (r != null) return r
    if (isType)
    {
      if (base != null) { r = f(base.id, "base"); if (r != null) return r }
    }
    else
    {
      r = f(type.id, "type"); if (r != null) return r
    }
    return meta.eachWhile(f)
  }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    val := get(name)
    if (val != null) return val
    return meta.trap(name, args)
  }

//////////////////////////////////////////////////////////////////////////
// Flags
//////////////////////////////////////////////////////////////////////////

  virtual SpecFlavor flavor() { SpecFlavor.slot }

  Bool isType() { flavor.isType }

  Bool hasFlag(Int flag) { flags.and(flag) != 0 }

  const Int flags

  Type fantomType() { binding.type }
}

**************************************************************************
** MSpecInit
**************************************************************************

@Js
const class MSpecInit
{
  new make(|This| f) { f(this) }
  const FileLoc loc
  const Lib? lib
  const XetoSpec? parent
  const Str name
  const Str? qname
  const XetoSpec? base
  const XetoSpec type
  const Dict meta
  const Dict metaOwn
  const SpecMap slots
  const SpecMap slotsOwn
  const SpecMap globalsOwn
  const Int flags
  const MSpecArgs args
  const SpecBinding? binding
}

**************************************************************************
** XetoSpec
**************************************************************************

**
** XetoSpec is the referential proxy for MSpec
**
@Js
const class XetoSpec : Spec, Dict, CSpec
{
  new make() {}

  new makem(MSpec m) { this.m = m }

  override Lib lib() { m.lib }

  override final Spec? parent() { m.parent }

  override final Ref id() { m.id }

  override final Str name() { m.name }

  override final Str qname() { m.qname }

  override final Spec type() { m.type }

  override final Spec? base() { m.base }

  override final Dict metaOwn() { m.metaOwn }

  override final Dict meta() { m.meta }

  override final SpecMap membersOwn() { XetoUtil.membersOwn(this) }

  override final SpecMap members() { XetoUtil.members(this) }

  override final Spec? member(Str n, Bool c := true) { XetoUtil.member(this, n, c) }

  override final Bool hasSlots() { m.hasSlots }

  override final SpecMap slotsOwn() { m.slotsOwn }

  override final SpecMap slots() { m.slots }

  override final Spec? slot(Str n, Bool c := true) { m.slot(n, c) }

  override final Spec? slotOwn(Str n, Bool c := true) { m.slotOwn(n, c) }

  override final SpecMap globalsOwn() { m.globalsOwn }

  override final SpecMap globals() { XetoUtil.globals(this) }

  override final Bool isa(Spec x) { XetoUtil.isa(this, (CSpec)x) }

  override final Bool cisa(CSpec x) { XetoUtil.isa(this, x) }

  override final FileLoc loc() { m.loc }

  override final SpecBinding binding() { m.binding }

  override final Bool isEmpty() { false }

  @Operator override final Obj? get(Str n) { m.get(n) }

  override final Bool has(Str n) { m.has(n) }

  override final Bool missing(Str n) { m.missing(n) }

  override final Void each(|Obj val, Str name| f) { m.each(f) }

  override final Obj? eachWhile(|Obj,Str->Obj?| f) { m.eachWhile(f) }

  override final Obj? trap(Str n, Obj?[]? a := null) { m.trap(n, a) }

  override final Str toStr() { m?.toStr ?: super.toStr }

  override final MSpecArgs args() { m.args }

  override final Spec? of(Bool checked := true) { m.args.of(checked) }

  override final Spec[]? ofs(Bool checked := true)  { m.args.ofs(checked) }

  override final Bool isSys() { lib.isSys }

  override final SpecEnum enum() { m.enum }

  override final CSpec? cenum(Str key, Bool checked := true) { m.enum.spec(key, checked) as CSpec }

  override final SpecFunc func() { m.func(this) }

  override final Void eachInherited(|Spec| f) { XetoUtil.eachInherited(this, f) }

  override final SpecFlavor flavor() { m.flavor }
  override final Bool isType()       { flavor.isType }
  override final Bool isMixin()      { flavor.isMixin }
  override final Bool isMeta()       { flavor.isMeta }
  override final Bool isSlot()       { flavor.isSlot && !isGlobal } // TODO

  override final Bool isNone()      { m.hasFlag(MSpecFlags.none) }
  override final Bool isSelf()      { m.hasFlag(MSpecFlags.self) }
  override final Bool isMaybe()     { m.hasFlag(MSpecFlags.maybe) }
  override final Bool isGlobal()    { m.hasFlag(MSpecFlags.global) || flavor.isGlobal } // TODO
  override final Bool isScalar()    { m.hasFlag(MSpecFlags.scalar) }
  override final Bool isMarker()    { m.hasFlag(MSpecFlags.marker) }
  override final Bool isRef()       { m.hasFlag(MSpecFlags.ref) }
  override final Bool isMultiRef()  { m.hasFlag(MSpecFlags.multiRef) }
  override final Bool isChoice()    { m.hasFlag(MSpecFlags.choice) }
  override final Bool isDict()      { m.hasFlag(MSpecFlags.dict) }
  override final Bool isList()      { m.hasFlag(MSpecFlags.list) }
  override final Bool isQuery()     { m.hasFlag(MSpecFlags.query) }
  override final Bool isFunc()      { m.hasFlag(MSpecFlags.func) }
  override final Bool isInterface() { m.hasFlag(MSpecFlags.interface) }
  override final Bool isComp()      { m.hasFlag(MSpecFlags.comp) }
  override final Bool isEnum()      { m.hasFlag(MSpecFlags.enum) }
  override final Bool isAnd()       { m.hasFlag(MSpecFlags.and) }
  override final Bool isOr()        { m.hasFlag(MSpecFlags.or) }
  override final Bool isCompound()  { CSpec.super.isCompound }

  override final Bool isAst() { false }

  override final XetoSpec asm() { this }

  override final Int flags() { m.flags }

  override final CSpec? cbase() { m.base }

  override final CSpec ctype() { m.type }

  override final CSpec? cparent() { m.parent }

  override final Dict cmeta() { m.meta }

  override final Bool cmetaHas(Str name) { m.meta.has(name) }

  override CSpec? cmember(Str n, Bool c := true) { member(n, c) as CSpec }

  override final Void cmembers(|CSpec, Str| f) { members.each |s, n| { f((CSpec)s, n) } }

  override final Void cslots(|CSpec, Str| f) { m.slots.each |s, n| { f((CSpec)s, n) } }

  override final Obj? cslotsWhile(|CSpec, Str->Obj?| f) { m.slots.eachWhile |s, n| { f((CSpec)s, n) } }

  override final XetoSpec? cof()  { of(false) }

  override final XetoSpec[]? cofs()  { ofs(false) as Obj }

  override final Type fantomType() { m.fantomType }

  override final Int inheritanceDigest() { m.inheritanceDigest(this) }

  const MSpec? m
}

