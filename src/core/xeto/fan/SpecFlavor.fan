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

  ** Slot spec under a parent
  slot

  ** Is this a lib top-level type or mixin
  Bool isTop() { this === type || this === mixIn }

  ** Is this the type flavor
  Bool isType() { this === type }

  ** Is this the mixin flavor
  Bool isMixin() { this === mixIn }

  ** Is this a slot or global
  Bool isMember() { this === slot || this === global }

  ** Is this the top-level global slot flavor
  Bool isGlobal() { this === global }

  ** Is this the slot flavor
  Bool isSlot() { this === slot }

}

