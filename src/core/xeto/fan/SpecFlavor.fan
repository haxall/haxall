//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Dec 2024  Brian Frank  Creation
//

**
** Flavor of spec: type, global, meta, or slot
**
@NoDoc @Js
enum class SpecFlavor
{
  ** Top level type spec
  type,

  ** Type mixin
  mixIn,

  ** Top level global slot spec
  global,

  ** Top level function spec
  func,

  ** Slot spec under a parent
  slot

  ** Is this the type flavor
  Bool isType() { this === type }

  ** Is this the mixin flavor
  Bool isMixin() { this === mixIn }

  ** Is this the top-level global slot flavor
  Bool isGlobal() { this === global }

  ** Is this a top-level func flavor
  Bool isFunc() { this === func }

  ** Is this the slot flavor
  Bool isSlot() { this === slot }

  ** Is this a lib top-level spec: type, global, func,  or meta
  Bool isTop() { this !== slot }
}

