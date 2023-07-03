//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//

using util

**
** AST scalar value
**
@Js
internal class AScalar
{
  ** Constructor
  new make(FileLoc loc, Str str, Obj? asm := null)
  {
    this.loc    = loc
    this.str    = str
    this.asmRef = asm
  }

  ** Source code location
  const FileLoc loc

  ** Encoded string
  const Str str

  ** Is this scalar value already parsed into its final value
  Bool isAsm() { asmRef != null }

  ** Assembled value - raise exception if not assembled yet
  Obj asm() { asmRef ?: throw NotAssembledErr() }

  ** Assembled value either passed in constructor or parsed in Reify
  Obj? asmRef

  ** Return quoted string encoding
  override Str toStr() { str.toCode }
}

