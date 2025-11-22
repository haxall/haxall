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
** RSpec stores spec info during decoding phase
**
@Js
internal class RSpec: SpecBindingInfo
{
  new make(Str libName, RSpec? parent, Str name)
  {
    this.libName  = libName
    this.asm      = XetoSpec()
    this.parent   = parent
    this.name     = name
  }

  const Str libName
  const XetoSpec asm
  const override Str name
  RSpec? parent { private set }

  override Str qname()
  {
    if (parent != null) return parent.qname + "." + name
    return libName + "::" + name
  }

  // decoded by XetoBinaryReader
  SpecFlavor flavor := SpecFlavor.slot
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
  XetoSpec? type
  XetoSpec? base
  Dict? metaOwn
  Dict? meta
  SpecMap? slotsOwn
  SpecMap? slots
  SpecMap? globalsOwn
  SpecBinding? bindingRef

  MSpecArgs args := MSpecArgs.nil

  Int flags
  Bool isEnum() { hasFlag(MSpecFlags.enum) }
  Bool hasFlag(Int mask) { flags.and(mask) != 0 }

 override Bool isInterface() { hasFlag(MSpecFlags.interface) }

  override CSpec? cbase() { base }

  override Str toStr() { name }
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

