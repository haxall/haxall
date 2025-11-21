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

**
** RSpec is the remote loader AST of a spec during decoding phase
**
@Js
internal class RSpec : CSpec
{
  new make(Str libName, RSpec? parent, Str name)
  {
    this.libName  = libName
    this.asm      = XetoSpec()
    this.parent   = parent
    this.name     = name
  }

  const Str libName
  const override XetoSpec asm
  const override Str name
  RSpec? parent { private set }

  // decoded by XetoBinaryReader
  override SpecFlavor flavor := SpecFlavor.slot
  RSpecRef? baseIn
  RSpecRef? typeIn
  Dict? metaOwnIn
  Dict? metaIn
  Str[]? metaInheritedIn
  RSpec[]? slotsOwnIn
  RSpec[]? globalsOwnIn
  RSpecRef[]? slotsInheritedIn

  // RemoteLoader.loadSpec
  Bool isLoaded
  CSpec? type
  CSpec? base
  Dict? metaOwn
  Dict? meta
  MSpecMap? slotsOwn
  MSpecMap? slots
  MSpecMap? globalsOwn
  SpecBinding? bindingRef

  override Bool hasSlots() { !slots.isEmpty }

  // CSpec
  override Bool isAst() { true }
  override Str qname()
  {
    if (parent != null) return parent.qname + "." + name
    return libName + "::" + name
  }
  override Ref id() { throw UnsupportedErr() }
  override SpecBinding binding() { bindingRef ?: throw Err("Binding not assigned") }
  override CSpec ctype() { type }
  override CSpec? cbase() { base }
  override CSpec? cparent() { parent }
  override Dict cmeta() { meta ?: throw Err(name) }
  override Bool cmetaHas(Str name) { cmeta.has(name) }
  override CSpec? cmember(Str n, Bool c := true) { throw UnsupportedErr() }
  override Void cslots(|CSpec, Str| f) { slots.each |s| { f((CSpec)s, s.name) } }
  override Obj? cslotsWhile(|CSpec, Str->Obj?| f) { slots.eachWhile |s| { f((CSpec)s, s.name) } }
  override CSpec? cenum(Str key, Bool checked := true) { throw UnsupportedErr() }
  override Bool cisa(CSpec x) { XetoUtil.isa(this, x) }
  override CSpec? cof
  override CSpec[]? cofs
  override Str toStr() { name }
  override MSpecArgs args := MSpecArgs.nil  // TODO

  override final Bool isSys() { libName =="sys" }

  // flags
  override Int flags
  override Bool isScalar()    { hasFlag(MSpecFlags.scalar) }
  override Bool isMarker()    { hasFlag(MSpecFlags.marker) }
  override Bool isRef()       { hasFlag(MSpecFlags.ref) }
  override Bool isMultiRef()  { hasFlag(MSpecFlags.multiRef) }
  override Bool isChoice()    { hasFlag(MSpecFlags.choice) }
  override Bool isDict()      { hasFlag(MSpecFlags.dict) }
  override Bool isList()      { hasFlag(MSpecFlags.list) }
  override Bool isMaybe()     { hasFlag(MSpecFlags.maybe) }
  override Bool isGlobal()    { hasFlag(MSpecFlags.global) }
  override Bool isQuery()     { hasFlag(MSpecFlags.query) }
  override Bool isFunc()      { hasFlag(MSpecFlags.func) }
  override Bool isInterface() { hasFlag(MSpecFlags.interface) }
  override Bool isComp()      { hasFlag(MSpecFlags.comp) }
  override Bool isNone()      { hasFlag(MSpecFlags.none) }
  override Bool isSelf()      { hasFlag(MSpecFlags.self) }
  override Bool isEnum()      { hasFlag(MSpecFlags.enum) }
  override Bool isAnd()       { hasFlag(MSpecFlags.and) }
  override Bool isOr()        { hasFlag(MSpecFlags.or) }
  Bool hasFlag(Int mask) { flags.and(mask) != 0 }
}

**************************************************************************
** RSpecRef
**************************************************************************

@Js
internal const class RSpecRef
{
  new make(Str lib, Str type, Str slot, Str[]? more)
  {
    this.lib  = lib
    this.type = type
    this.slot = slot
    this.more = more
  }

  const Str lib       // lib name
  const Str type      // top-level type name code
  const Str slot      // first level slot or zero if type only
  const Str[]? more   // slot path below first slot (uncommon)

  override Str toStr() { "$lib $type $slot $more" }
}

