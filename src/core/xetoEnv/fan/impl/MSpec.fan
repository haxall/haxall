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
  new make(FileLoc loc, XetoSpec? parent, Int nameCode, Str name, XetoSpec? base, XetoType type, MNameDict meta, MNameDict metaOwn, MSlots slots, MSlots slotsOwn, Int flags, MSpecArgs args)
  {
    this.loc      = loc
    this.nameCode = nameCode
    this.name     = name
    this.parent   = parent
    this.base     = base
    this.type     = type
    this.meta     = meta
    this.metaOwn  = metaOwn
    this.slots    = slots
    this.slotsOwn = slotsOwn
    this.flags    = flags
    this.args     = args
  }

  virtual XetoLib lib() { parent.lib }

  const FileLoc loc

  const Int nameCode

  const Str name

  const XetoSpec? parent

  virtual haystack::Ref id() { haystack::Ref(qname) }

  virtual Str qname() { parent.qname + "." + name }

  const XetoType type

  const XetoSpec? base

  const MNameDict meta

  const MNameDict metaOwn

  const MSlots slots

  const MSlots slotsOwn

  Bool hasSlots() { !slots.isEmpty }

  XetoSpec? slot(Str name, Bool checked := true) { slots.get(name, checked) }

  XetoSpec? slotOwn(Str name, Bool checked := true) { slotsOwn.get(name, checked) }

  const MSpecArgs args

  override Str toStr() { qname }

  virtual SpecFactory factory() { type.factory }

  virtual MEnum enum() { throw UnsupportedErr("Spec is not enum: $qname") }

//////////////////////////////////////////////////////////////////////////
// Dict Representation
//////////////////////////////////////////////////////////////////////////

  const static Ref specSpecRef := haystack::Ref("sys::Spec")

  Obj? get(Str name, Obj? def := null)
  {
    if (name == "id")   return id
    if (name == "spec") return specSpecRef
    if (isType)
    {
      if (name == "base") return base?.id ?: def
    }
    else
    {
      if (name == "type") return type.id
    }
    return meta.get(name, def)
  }

  Bool has(Str name)
  {
    if (name == "id")   return true
    if (name == "spec") return true
    if (name == "base") return isType && base != null
    if (name == "type") return !isType
    return meta.has(name)
  }

  Bool missing(Str name)
  {
    if (name == "id")   return false
    if (name == "spec") return false
    if (name == "base") return !isType || base == null
    if (name == "type") return isType
    return meta.missing(name)
  }

  Void each(|Obj val, Str name| f)
  {
    f(id, "id")
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
    val := get(name, null)
    if (val != null) return val
    return meta.trap(name, args)
  }

//////////////////////////////////////////////////////////////////////////
// Flags
//////////////////////////////////////////////////////////////////////////

  virtual Bool isType() { false }

  virtual Bool isGlobal() { false }

  Bool hasFlag(Int flag) { flags.and(flag) != 0 }

  const Int flags

  Type fantomType() { factory.type }
}

**************************************************************************
** MDerivedSpec
**************************************************************************

@Js
internal const class MDerivedSpec : MSpec
{
  static const AtomicInt counter := AtomicInt()

  new make(XetoSpec? parent, Int nameCode, Str name, XetoSpec base, MNameDict meta, MSlots slots, Int flags)
    : super(FileLoc.synthetic, parent, nameCode, name, base, base.type, meta, meta, slots, slots, flags, MSpecArgs.nil) // TODO: meta vs metaOwn, slots vs slotsOwn
  {
    this.qname = "derived" + counter.getAndIncrement + "::" + name
  }

  const override Str qname
}

**************************************************************************
** XetoSpec
**************************************************************************

**
** XetoSpec is the referential proxy for MSpec
**
@Js
const class XetoSpec : Spec, haystack::Dict, CSpec
{
  new make() {}

  new makem(MSpec m) { this.m = m }

  override Lib lib() { m.lib }

  override final Spec? parent() { m.parent }

  override final haystack::Ref id() { m.id }

  override final haystack::Ref _id() { m.id }

  override final Str name() { m.name }

  override final Str qname() { m.qname }

  override final Spec type() { m.type }

  override final Spec? base() { m.base }

  override final Dict meta() { m.meta }

  override final Dict metaOwn() { m.metaOwn }

  override final Bool hasSlots() { m.hasSlots }

  override final SpecSlots slotsOwn() { m.slotsOwn }

  override final SpecSlots slots() { m.slots }

  override final Spec? slot(Str n, Bool c := true) { m.slot(n, c) }

  override final Spec? slotOwn(Str n, Bool c := true) { m.slotOwn(n, c) }

  override final Bool isa(Spec x) { XetoUtil.isa(this, (CSpec)x) }

  override final Bool cisa(CSpec x) { XetoUtil.isa(this, x) }

  override final FileLoc loc() { m.loc }

  override final SpecFactory factory() { m.factory }

  override final Bool isEmpty() { false }

  @Operator override final Obj? get(Str n, Obj? d := null) { m.get(n, d) }

  override final Bool has(Str n) { m.has(n) }

  override final Bool missing(Str n) { m.missing(n) }

  override final Void each(|Obj val, Str name| f) { m.each(f) }

  override final Obj? eachWhile(|Obj,Str->Obj?| f) { m.eachWhile(f) }

  override final Obj? trap(Str n, Obj?[]? a := null) { m.trap(n, a) }

  override final Str toStr() { m?.toStr ?: super.toStr }

  override final MSpecArgs args() { m.args }

  override final Spec? of(Bool checked := true) { m.args.of(checked) }

  override final Spec[]? ofs(Bool checked := true)  { m.args.ofs(checked) }

  override final Bool isType() { m.isType }

  override final Bool isGlobal() { m.isGlobal }

  override final Bool isSys() { lib.isSys }

  override final SpecEnum enum() { m.enum }

  override final CSpec? cenum(Str key, Bool checked := true) { m.enum.spec(key, checked) as CSpec }

  override final Bool isNone()    { m.hasFlag(MSpecFlags.none) }
  override final Bool isSelf()    { m.hasFlag(MSpecFlags.self) }
  override final Bool isMaybe()   { m.hasFlag(MSpecFlags.maybe) }
  override final Bool isScalar()  { m.hasFlag(MSpecFlags.scalar) }
  override final Bool isMarker()  { m.hasFlag(MSpecFlags.marker) }
  override final Bool isChoice()  { m.hasFlag(MSpecFlags.choice) }
  override final Bool isDict()    { m.hasFlag(MSpecFlags.dict) }
  override final Bool isList()    { m.hasFlag(MSpecFlags.list) }
  override final Bool isQuery()   { m.hasFlag(MSpecFlags.query) }
  override final Bool isFunc()    { m.hasFlag(MSpecFlags.func) }
  override final Bool isInterface() { m.hasFlag(MSpecFlags.interface) }
  override final Bool isComp()    { m.hasFlag(MSpecFlags.comp) }
  override final Bool isEnum()    { m.hasFlag(MSpecFlags.enum) }
  override final Bool isAnd()     { m.hasFlag(MSpecFlags.and) }
  override final Bool isOr()      { m.hasFlag(MSpecFlags.or) }

  override final Bool isAst() { false }

  override final XetoSpec asm() { this }

  override final Int flags() { m.flags }

  override final CSpec? cbase() { m.base }

  override final CSpec ctype() { m.type }

  override final CSpec? cparent() { m.parent }

  override final MNameDict cmeta() { m.meta }

  override final CSpec? cslot(Str n, Bool c := true) { m.slot(n, c) }

  override final Void cslots(|CSpec, Str| f) { m.slots.map.each(f) }

  override final XetoSpec[]? cofs()  { ofs(false) }

  override final Type fantomType() { m.fantomType }

  const MSpec? m
}

