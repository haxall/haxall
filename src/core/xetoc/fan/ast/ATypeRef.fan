//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//   3 Jul 2023  Brian Frank  Redesign the AST
//

using util
using xeto

**
** AST for type signature to reference a type
**
@Js
internal class ATypeRef : AData
{
  ** Constructor
  new make(FileLoc loc, AName name)
    : super(loc, null)
  {
    this.name = name
  }

  ** Type name
  const AName name

  ** Return debug string
  override Str toStr() { name.toStr }

  CSpec deref() { throw NotReadyErr() }
}

