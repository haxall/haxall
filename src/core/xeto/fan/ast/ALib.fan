//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//

using util

**
** AST DataLib
**
@Js
internal class ALib : ASpec
{
  ** Constructor
  new make(FileLoc loc, Str qname)
    : super(loc, null, "", XetoLib())
  {
    this.qname = qname
  }

  ** Node type
  override ANodeType nodeType() { ANodeType.lib }

  ** Return true
  override Bool isLib() { true }

  ** Assembled DataLib reference
  override XetoLib asm() { asmRef }

  ** Construct type
  override AObj makeChild(FileLoc loc, Str name) { AType(loc, this, name) }

  ** Qualified name "foo.bar.baz"
  override const Str qname
}