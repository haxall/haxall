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
internal mixin CSpec : CNode
{
  ** Return if this an AST ASpec
  abstract Bool isAst()

  ** Assembled XetoSpec (stub only in AST until Assemble step)
  override abstract XetoSpec asm()

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

**************************************************************************
** CNode
**************************************************************************

@Js
internal mixin CNode
{
  ** Required for covariant conflict so that signature matches ANode
  abstract Obj asm()
}


