//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Feb 2023  Brian Frank  Creation
//

using util
using haystack

**
** AST system type references
**
internal class ASys
{
  ASpecRef obj    := init("Obj")
  ASpecRef none   := init("None")
  ASpecRef marker := init("Marker")
  ASpecRef str    := init("Str")
  ASpecRef ref    := init("Ref")
  ASpecRef dict   := init("Dict")
  ASpecRef list   := init("List")
  ASpecRef and    := init("And")
  ASpecRef or     := init("Or")
  ASpecRef lib    := init("Lib")
  ASpecRef spec   := init("Spec")
  ASpecRef query  := init("Query")

  Void each(|ASpecRef| f)
  {
    typeof.fields.each |field|
    {
      ref := field.get(this) as ASpecRef
      if (ref != null) f(ref)
    }
  }

  private static ASpecRef init(Str name)
  {
    ASpecRef(FileLoc.synthetic, ASimpleName("sys", name))
  }

  AScalar markerScalar(FileLoc loc)
  {
    AScalar(loc, marker, Marker.val.toStr, Marker.val)
  }
}

