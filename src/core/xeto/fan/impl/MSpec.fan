//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using concurrent
using util
using data
using haystack

**
** Implementation of DataSpec wrapped by XetoSpec
**
@Js
internal const class MSpec
{
  new make(FileLoc loc, XetoSpec? parent, Str name, XetoSpec? base, XetoType type, DataDict meta, DataDict metaOwn, MSlots slots, MSlots slotsOwn, Int flags)
  {
    this.loc      = loc
    this.parent   = parent
    this.name     = name
    this.base     = base
    this.type     = type
    this.meta     = meta
    this.own      = metaOwn
    this.slots    = slots
    this.slotsOwn = slotsOwn
    this.flags    = flags
  }

  virtual XetoEnv env() { parent.env }

  const FileLoc loc

  const XetoSpec? parent

  const Str name

  virtual Str qname() { parent.qname + "." + name }

  const XetoType type

  const XetoSpec? base

  const DataDict meta

  const DataDict own

  const MSlots slots

  const MSlots slotsOwn

  XetoSpec? slot(Str name, Bool checked := true) { slots.get(name, checked) }

  XetoSpec? slotOwn(Str name, Bool checked := true) { slotsOwn.get(name, checked) }

  override Str toStr() { qname }

  virtual DataSpec spec() { env.sys.spec }

//////////////////////////////////////////////////////////////////////////
// Effective Meta
//////////////////////////////////////////////////////////////////////////

  Bool isEmpty() { meta.isEmpty }
  Obj? get(Str name, Obj? def := null) { meta.get(name, def) }
  Bool has(Str name) { meta.has(name) }
  Bool missing(Str name) { meta.missing(name) }
  Void each(|Obj val, Str name| f) { meta.each(f) }
  Obj? eachWhile(|Obj val, Str name->Obj?| f) { meta.eachWhile(f) }
  override Obj? trap(Str name, Obj?[]? args := null) { meta.trap(name, args) }

//////////////////////////////////////////////////////////////////////////
// Flags
//////////////////////////////////////////////////////////////////////////

  virtual Bool isLib() { false }

  virtual Bool isType() { false }

  Bool hasFlag(Int flag) { flags.and(flag) != 0 }

  const Int flags

}

**************************************************************************
** MDerivedSpec
**************************************************************************

@Js
internal const class MDerivedSpec : MSpec
{
  static const AtomicInt counter := AtomicInt()

  new make(XetoEnv env, Str name, XetoSpec base, DataDict meta, MSlots slots, Int flags)
    : super(FileLoc.synthetic, null, name, base, base.type, meta, meta, slots, slots, flags) // TODO: meta vs metaOwn, slots vs slotsOwn
  {
    this.env = env
    this.qname = "derived" + counter.getAndIncrement + "::" + name
  }

  const override XetoEnv env
  const override Str qname
}

**************************************************************************
** MSpecFlags
**************************************************************************

@Js
internal const class MSpecFlags
{
  static const Int maybe  := 0x0001
  static const Int marker := 0x0002
  static const Int scalar := 0x0004
  static const Int seq    := 0x0008
  static const Int dict   := 0x0010
  static const Int list   := 0x0020
  static const Int query  := 0x0040

  static Str flagsToStr(Int flags)
  {
    s := StrBuf()
    MSpecFlags#.fields.each |f|
    {
      if (f.isStatic && f.type == Int#)
      {
        has := flags.and(f.get(null)) != 0
        if (has) s.join(f.name, ",")
      }
    }
    return "{" + s.toStr + "}"
  }
}

**************************************************************************
** XetoSpec
**************************************************************************

**
** XetoSpec is the referential proxy for MSpec
**
@Js
internal const class XetoSpec : DataSpec, Dict, CSpec
{
  new make() {}

  new makem(MSpec m) { this.m = m }

  override final DataEnv env() { m.env }

  override final DataSpec? parent() { m.parent }

  override final Str name() { m.name }

  override final Str qname() { m.qname }

  override final DataType type() { m.type }

  override final DataSpec? base() { m.base }

  override final DataDict own() { m.own }

  override final DataSlots slotsOwn() { m.slotsOwn }

  override final DataSlots slots() { m.slots }

  override final DataSpec? slot(Str n, Bool c := true) { m.slot(n, c) }

  override final DataSpec? slotOwn(Str n, Bool c := true) { m.slotOwn(n, c) }

  override final Bool isa(DataSpec x) { XetoUtil.isa(this, x, true) }

  override final Bool fits(DataSpec that) { Fitter(m.env, m.env.nilContext, m.env.dict0).specFits(this, that) }

  override final FileLoc loc() { m.loc }

  override final DataSpec spec() { m.spec }

  override final Bool isEmpty() { m.isEmpty }

  @Operator override final Obj? get(Str n, Obj? d := null) { m.get(n, d) }

  override final Bool has(Str n) { m.has(n) }

  override final Bool missing(Str n) { m.missing(n) }

  override final Void each(|Obj val, Str name| f) { m.each(f) }

  override final Obj? eachWhile(|Obj,Str->Obj?| f) { m.eachWhile(f) }

  override final Obj? trap(Str n, Obj?[]? a := null) { m.trap(n, a) }

  override final Str toStr() { m?.toStr ?: super.toStr }

  override final Bool isCompound()  { XetoUtil.isCompound(this) }

  override final DataSpec[]? ofs(Bool checked := true)  { XetoUtil.ofs(this, checked) }

  override final Bool isNone() { XetoUtil.isNone(this) }

  override final Bool isAnd() { XetoUtil.isAnd(this) }

  override final Bool isOr() { XetoUtil.isOr(this) }

  override final Bool isLib() { m.isLib }

  override final Bool isType() { m.isType }

  override final Bool isMaybe()  { m.hasFlag(MSpecFlags.maybe) }
  override final Bool isScalar() { m.hasFlag(MSpecFlags.scalar) }
  override final Bool isMarker() { m.hasFlag(MSpecFlags.marker) }
  override final Bool isSeq()    { m.hasFlag(MSpecFlags.seq) }
  override final Bool isDict()   { m.hasFlag(MSpecFlags.dict) }
  override final Bool isList()   { m.hasFlag(MSpecFlags.list) }
  override final Bool isQuery()  { m.hasFlag(MSpecFlags.query) }

  override final Bool isAst() { false }

  override final XetoSpec asm() { this }

  override final Int flags() { m.flags }

  override final CSpec? cbase() { m.base }

  override final CSpec? ctype() { m.type }

  override final DataDict cmeta() { m.meta }

  override final CSpec? cslot(Str n, Bool c := true) { m.slot(n, c) }

  override final Str:CSpec cslots() { m.slots.map }

  override final XetoSpec[]? cofs()  { ofs(false) }

  const MSpec? m
}