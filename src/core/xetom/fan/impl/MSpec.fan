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

**
** Implementation of Spec wrapped by XetoSpec
**
@Js
const class MSpec
{
  static MSpec factory(XetoSpec asm, SpecFlavor flavor, MSpecInit init)
  {
    MSpec? m
    switch (flavor)
    {
      case SpecFlavor.type:  m = MType(init)
      case SpecFlavor.mixIn: m = MMixin(init)
      default:               m = MSpec(init)
    }
    XetoSpec#m->setConst(asm, m)
    return m
  }

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

  Bool hasSlots() { !slots.isEmpty }

  XetoSpec? slot(Str name, Bool checked := true) { slots.get(name, checked) }

  XetoSpec? slotOwn(Str name, Bool checked := true) { slotsOwn.get(name, checked) }

  virtual SpecMap globalsOwn() { SpecMap.empty }

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
// Flags
//////////////////////////////////////////////////////////////////////////

  virtual SpecFlavor flavor()
  {
    hasFlag(MSpecFlags.global) ? SpecFlavor.global : SpecFlavor.slot
  }

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
  const SpecMap? globalsOwn
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
const class XetoSpec : Spec, CNode
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

  override final SpecMap membersOwn() { SpecMap(slotsOwn, globalsOwn) }

  override final SpecMap members() { SpecMap(slots, globals) }

  override final Spec? member(Str n, Bool c := true) { XetoUtil.member(this, n, c) }

  override final SpecMap slotsOwn() { m.slotsOwn }

  override final SpecMap slots() { m.slots }

  override final Spec? slot(Str n, Bool c := true) { m.slot(n, c) }

  override final Spec? slotOwn(Str n, Bool c := true) { m.slotOwn(n, c) }

  override final SpecMap globalsOwn() { m.globalsOwn }

  override final once SpecMap globals() { XetoUtil.globals(this) }

  override final Bool isa(Spec x) { XetoUtil.isa(this, x) }

  override final FileLoc loc() { m.loc }

  override final SpecBinding binding() { m.binding }

  override final Bool isEmpty() { false }

  @Operator override Obj? get(Str name) { XetoUtil.specGet(this, name) }

  override Bool has(Str name) { XetoUtil.specHas(this, name) }

  override Bool missing(Str name) { XetoUtil.specMissing(this, name) }

  override Void each(|Obj val, Str name| f) { XetoUtil.specEach(this, f) }

  override Obj? eachWhile(|Obj val, Str name->Obj?| f) { XetoUtil.specEachWhile(this, f) }

  override Obj? trap(Str name, Obj?[]? args := null) { XetoUtil.specTrap(this, name, args) }

  override final Str toStr() { m?.toStr ?: super.toStr }

  override final Spec? of(Bool checked := true) { m.args.of(checked) }

  override final Spec[]? ofs(Bool checked := true)  { m.args.ofs(checked) }

  override final SpecEnum enum() { m.enum }

  override final SpecFunc func() { m.func(this) }

  override final Void eachInherited(|Spec| f) { XetoUtil.eachInherited(this, f) }

  override final SpecFlavor flavor() { m.flavor }
  override final Bool isType()       { flavor.isType }
  override final Bool isMixin()      { flavor.isMixin }
  override final Bool isMember()     { flavor.isMember }
  override final Bool isSlot()       { flavor.isSlot }
  override final Bool isGlobal()     { flavor.isGlobal }

  override final Bool isNone()      { m.hasFlag(MSpecFlags.none) }
  override final Bool isSelf()      { m.hasFlag(MSpecFlags.self) }
  override final Bool isMaybe()     { m.hasFlag(MSpecFlags.maybe) }
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
  override final Bool isTransient() { m.hasFlag(MSpecFlags.transient) }
  override final Bool isHaystack()  { m.hasFlag(MSpecFlags.haystack) }
  override final Bool isSys()       { lib.isSys }
  override final Bool isCompound()  { (isAnd || isOr) && ofs(false) != null }

  override final Bool isAst() { false }

  override final Spec asm() { this }

  override final Int flags() { m.flags }

  override final Type fantomType() { m.fantomType }

  override final Int inheritanceDigest() { m.inheritanceDigest(this) }

  MSpecArgs args() { m.args }

  const MSpec? m
}

