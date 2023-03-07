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

**
** Implementation of DataSpec wrapped by XetoSpec
**
@Js
internal const class MSpec
{
  new make(FileLoc loc, XetoSpec? parent, Str name, XetoSpec? base, XetoType type, DataDict own, MSlots slotsOwn)
  {
    this.loc      = loc
    this.parent   = parent
    this.name     = name
    this.base     = base
    this.type     = type
    this.own      = own
    this.slotsOwn = slotsOwn
  }

  virtual XetoEnv env() { parent.env }

  const FileLoc loc

  const XetoSpec? parent

  const Str name

  virtual Str qname() { parent.qname + "." + name }

  const XetoType type

  const XetoSpec? base

  once MSlots slots() { XetoUtil.inheritSlots(this) }

  const MSlots slotsOwn

  XetoSpec? slot(Str name, Bool checked := true) { slots.get(name, checked) }

  XetoSpec? slotOwn(Str name, Bool checked := true) { slotsOwn.get(name, checked) }

  override Str toStr() { qname }

  const DataDict own

  virtual DataSpec spec() { env.sys.spec }

//////////////////////////////////////////////////////////////////////////
// Effective Meta
//////////////////////////////////////////////////////////////////////////

  DataDict meta()
  {
    meta := metaRef.val
    if (meta != null) return meta
    metaRef.compareAndSet(null, XetoUtil.inheritMeta(this))
    return metaRef.val
  }
  private const AtomicRef metaRef := AtomicRef()

  Bool isEmpty() { meta.isEmpty }
  Obj? get(Str name, Obj? def := null) { meta.get(name, def) }
  Bool has(Str name) { meta.has(name) }
  Bool missing(Str name) { meta.missing(name) }
  Void each(|Obj val, Str name| f) { meta.each(f) }
  Obj? eachWhile(|Obj val, Str name->Obj?| f) { meta.eachWhile(f) }
  override Obj? trap(Str name, Obj?[]? args := null) { meta.trap(name, args) }

}

**************************************************************************
** XetoSpec
**************************************************************************

**
** XetoSpec is the referential proxy for MSpec
**
@Js
internal const class XetoSpec : DataSpec
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

  override final Bool isa(DataSpec x) { XetoUtil.isa(this, x) }

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

  const MSpec? m
}