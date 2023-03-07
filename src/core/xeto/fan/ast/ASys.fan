//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Feb 2023  Brian Frank  Creation
//

using util

**
** AST system type references
**
@Js
internal class ASys
{
  ARef obj    := init("Obj")
  ARef marker := init("Marker")
  ARef str    := init("Str")
  ARef dict   := init("Dict")
  ARef list   := init("List")
  ARef and    := init("And")
  ARef or     := init("Or")
  ARef maybe  := init("Maybe")
  ARef lib    := init("Lib")

  Void each(|ARef| f)
  {
    typeof.fields.each |field|
    {
      ref := field.get(this) as ARef
      if (ref != null) f(ref)
    }
  }

  private static ARef init(Str name) { ARef(FileLoc.synthetic, AName("sys", name)) }

}