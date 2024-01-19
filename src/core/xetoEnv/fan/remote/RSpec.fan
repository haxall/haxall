//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Aug 2022  Brian Frank  Creation
//

using util
using concurrent
using xeto
using haystack::Dict

**
** RSpec is the remote loader AST of a spec during decoding phase
**
@Js
internal class RSpec : CSpec, NameDictReader
{
  new make(Str libName, XetoSpec asm, RSpec? parent, Int nameCode, Str name)
  {
    this.libName  = libName
    this.asm      = asm
    this.parent   = parent
    this.isType   = parent == null && !name[0].isLower
    this.isGlobal = parent == null && name[0].isLower
    this.name     = name
    this.nameCode = nameCode
  }

  const Str libName
  const override XetoSpec asm
  const override Str name
  const Int nameCode
  RSpec? parent { private set }
  const override Bool isType
  const override Bool isGlobal

  // decoded by XetoBinaryReader
  RSpecRef? baseIn
  RSpecRef? typeIn
  NameDict? metaIn
  RSpec[]? slotsIn

  // RemoteLoader.loadSpec
  Bool isLoaded
  CSpec? type
  CSpec? base
  MNameDict? metaOwn
  MNameDict? meta
  MSlots? slotsOwn
  MSlots? slots

  override Bool hasSlots() { !slots.isEmpty }

  // CSpec
  override Bool isAst() { true }
  override Str qname()
  {
    if (parent != null) return parent.qname + "." + name
    return libName + "::" + name
  }
  override haystack::Ref id() { throw UnsupportedErr() }
  override SpecFactory factory() { throw UnsupportedErr() }
  override CSpec ctype() { type }
  override CSpec? cbase
  override CSpec? cparent() { parent }
  override MNameDict cmeta() { meta ?: throw Err(name) }
  override CSpec? cslot(Str name, Bool checked := true) { throw UnsupportedErr() }
  override Void cslots(|CSpec, Str| f) { slots.each |s| { f((CSpec)s, s.name) } }
  override CSpec? cenum(Str key, Bool checked := true) { throw UnsupportedErr() }
  override Bool cisa(CSpec x) { XetoUtil.isa(this, x) }
  override CSpec[]? cofs
  override Str toStr() { name }
  override MSpecArgs args := MSpecArgs.nil  // TODO

  override final Bool isSys() { libName =="sys" }
  override final Bool isNone() { qname == "sys::None" }
  override final Bool isSelf() { qname == "sys::Self" }
  override final Bool isEnum() { base != null && base.qname == "sys::Enum" }
  override final Bool isBaseAnd() { base != null && base.qname == "sys::And" }
  override final Bool isBaseOr() { base != null && base.qname == "sys::Or" }

  // flags
  override Int flags
  override Bool isScalar() { hasFlag(MSpecFlags.scalar) }
  override Bool isMarker() { hasFlag(MSpecFlags.marker) }
  override Bool isChoice() { hasFlag(MSpecFlags.choice) }
  override Bool isDict()   { hasFlag(MSpecFlags.dict) }
  override Bool isList()   { hasFlag(MSpecFlags.list) }
  override Bool isMaybe()  { hasFlag(MSpecFlags.maybe) }
  override Bool isQuery()  { hasFlag(MSpecFlags.query) }
  Bool hasFlag(Int mask) { flags.and(mask) != 0 }

  // NameDictReader
  override Int readName() { slotsIn[readIndex].nameCode }
  override Obj? readVal() { slotsIn[readIndex++].asm }
  Int readIndex

}

**************************************************************************
** RSpecRef
**************************************************************************

@Js
internal const class RSpecRef
{
  new make(Int lib, Int type, Int slot, Int[]? more)
  {
    this.lib  = lib
    this.type = type
    this.slot = slot
    this.more = more
  }

  const Int lib       // lib name
  const Int type      // top-level type name code
  const Int slot      // first level slot or zero if type only
  const Int[]? more   // slot path below first slot (uncommon)

  override Str toStr() { "$lib $type $slot $more" }
}



