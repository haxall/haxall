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
  ** Top level type
  type,

  ** Top level global slot spec
  global,

  ** Top level meta spec
  meta,

  ** Slot spec under a parent
  slot

  ** Is this the type flavor
  Bool isType() { this === type }

  ** Is this the global flavor
  Bool isGlobal() { this === global }

  ** Is this the meta flavor
  Bool isMeta() { this === meta }

  ** Is this the slot flavor
  Bool isSlot() { this === slot }
}

