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
  new make(XetoSpec asm, RSpec? parent, Int nameCode, Str name)
  {
    this.asm      = asm
    this.parent   = parent
    this.isType   = parent == null
    this.name     = name
    this.nameCode = nameCode
  }

  const override XetoSpec asm
  const override Str name
  const Int nameCode
  const Bool isType
  RSpec? parent { private set }

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
  MSpecArgs? args := MSpecArgs.nil  // TODO

  // CSpec
  override Bool isAst() { true }
  override Str qname() { throw UnsupportedErr() }
  override haystack::Ref id() { throw UnsupportedErr() }
  override SpecFactory factory() { throw UnsupportedErr() }
  override CSpec? ctype
  override CSpec? cbase
  override MNameDict cmeta() { meta ?: throw Err(name) }
  override CSpec? cslot(Str name, Bool checked := true) { throw UnsupportedErr() }
  override Void cslots(|CSpec, Str| f) { slots.each |s| { f((CSpec)s, s.name) } }
  override CSpec[]? cofs
  override Str toStr() { name }

  // flags
  override Int flags
  override Bool isScalar() { hasFlag(MSpecFlags.scalar) }
  override Bool isList() { hasFlag(MSpecFlags.list) }
  override Bool isMaybe() { hasFlag(MSpecFlags.maybe) }
  override Bool isQuery() { hasFlag(MSpecFlags.query) }
  Bool hasFlag(Int mask) { flags.and(mask) != 0 }

  // NameDictReader
  override Int readName() { slotsIn[readIndex].nameCode }
  override Obj readVal() { slotsIn[readIndex++].asm }
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



