//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//

using util

**
** AST DataSpec
**
@Js
internal class ASpec : AObj
{
  ** Constructor
  new make(FileLoc loc, ASpec? parent, Str name, XetoSpec asm := XetoSpec())
    : super(loc, parent, name)
  {
    this.asmRef = asm
  }

  ** Node type
  override ANodeType nodeType() { ANodeType.spec }

  ** Return true
  override Bool isSpec() { true }

  ** Return 'asm' XetoSpec as the assembled value.  This is the
  ** reference to the DataSpec - we backpatch the "m" field in Assemble step
  override XetoSpec asm() { asmRef }
  const XetoSpec asmRef

  ** Construct nested spec
  override AObj makeChild(FileLoc loc, Str name) { ASpec(loc, this, name) }

}


