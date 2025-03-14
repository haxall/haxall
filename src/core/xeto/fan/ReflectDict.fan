//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Mar 2025  Brian Frank  Creation
//

using concurrent
using util

**
** ReflectDict is the analysis of a Dict against a namespace of specs
**
@NoDoc @Js
const mixin ReflectDict
{
  ** Source dict analyzed
  abstract Dict subject()

  ** Spec type of dict used for reflection
  abstract Spec spec()

  ** Reflected slots
  abstract ReflectSlot[] slots()

  ** Reflected slot by name
  abstract ReflectSlot? slot(Str name, Bool checked := true)

  ** Debug dump to the console
  @NoDoc abstract Void dump(Console con := Console.cur)

}

**************************************************************************
** ReflectSlot
**************************************************************************

**
** ReflectSlot models one name/value pair of a ReflectDict
**
@NoDoc @Js
const mixin ReflectSlot
{
  ** Name of the slot in dict
  abstract Str name()

  ** Spec of the slot as one of the following:
  **   - slot spec of dict spec
  **   - global spec if defined by namespace
  **   - fallback to spec of value type
  abstract Spec spec()

  ** Is this a choice virtual slot
  abstract Bool isChoice()

  ** Value of the slot in dict or null if not present in dict.
  ** If a choice val is Ref[] (regardless if multiChoice or not).
  abstract Obj? val()
}

