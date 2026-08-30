//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2026  Brian Frank  Creation
//

using xeto

**
** Icon represents a logical SVG icon name against installed manifest.
**
@Js @Gen
const mixin Icon
{
  ** Lookup icon by its name
  static new fromStr(Str name, Bool checked := true)
  {
    throw Err("TODO")
  }

  ** Blank icon (default value)
  static Icon blank() { throw Err("TODO") }

  ** Icon name key
  abstract Str name()

  ** Is the blank icon (default value)
  @NoDoc Bool isBlank() { name == "blank" }
}
