//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Nov 2023  Brian Frank  Creation
//

using concurrent

**
** Scalar represents typed scalars when not mapped to native Fantom class.
**
@Js
const final class Scalar
{
  ** Construct for spec qname and string value
  new make(Str qname, Str val)
  {
    this.qname = qname
    this.val   = val
  }

  ** Scalar type qualified name
  const Str qname

  ** String value
  const Str val

  ** Hash is composed of type and val
  override Int hash() { val.hash }

  ** Equality is base on qname and val
  override Bool equals(Obj? obj)
  {
    that := obj as Scalar
    if (that == null) return false
    return this.qname == that.qname && this.val == that.val
  }

  ** Return string value
  override Str toStr() { val }
}

