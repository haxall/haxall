//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Apr 2023  Brian Frank  Creation
//

using util

**
** CSpec is common API shared by both ASpec and XetoSpec
**
@Js
internal mixin CSpec
{
  ** Return if this an AST ASpec
  abstract Bool isAst()

  ** Simple name
  abstract Str name()

  ** Qualified name
  abstract Str qname()

  ** Base spec or null if this sys::Obj itself
  abstract CSpec? cbase()

  ** Lookup effective slot
  abstract CSpec? cslot(Str name, Bool checked := true)

  ** Get the effective slots as map
  abstract Str:CSpec cslots()
}


