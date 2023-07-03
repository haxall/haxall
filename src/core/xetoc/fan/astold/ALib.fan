//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//

using util

**
** AST Lib
**
@Js
internal class ALib : ASpec
{
  ** Constructor
  new make(FileLoc loc, Str qname)
    : super(loc, null, "", XetoSpec())
  {
    this.qname = qname
    this.asmLib = XetoLib()
  }

  ** Return true
  override Bool isLib() { true }

  ** Assembled Lib reference
  override XetoSpec asm() { throw Err("TODO") }
  const XetoLib asmLib

  ** Construct type
  override AObj makeChild(FileLoc loc, Str name) { AType(loc, this, name) }

  ** Qualified name "foo.bar.baz"
  override const Str qname

  ** Version parsed from lib.xeto
  Version? version
}