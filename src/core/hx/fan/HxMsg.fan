//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using haystack

**
** HxMsg provides simple immutable tuple to use for actor messages.
**
const class HxMsg
{
  ** Constructor with zero arguments
  new make0(Str id)
  {
    this.id = id
  }

  ** Constructor with one argument
  new make1(Str id, Obj? a)
  {
    this.id = id
    this.a  = a
  }

  ** Constructor with two arguments
  new make2(Str id, Obj? a, Obj? b)
  {
    this.id = id
    this.a  = a
    this.b  = b
  }

  ** Constructor with three arguments
  new make3(Str id, Obj? a, Obj? b, Obj? c)
  {
    this.id = id
    this.a  = a
    this.b  = b
    this.c  = c
  }

  ** Constructor with four arguments
  new make4(Str id, Obj? a, Obj? b, Obj? c, Obj? d)
  {
    this.id = id
    this.a  = a
    this.b  = b
    this.c  = c
    this.d  = d
  }

  ** Message identifier type
  const Str id

  ** Argument a
  const Obj? a

  ** Argument b
  const Obj? b

  ** Argument c
  const Obj? c

  ** Argument d
  const Obj? d

  ** Hash is based on id and arguments
  override Int hash()
  {
    hash := id.hash
    if (a != null) hash = hash.xor(a.hash)
    if (b != null) hash = hash.xor(b.hash)
    if (c != null) hash = hash.xor(c.hash)
    if (d != null) hash = hash.xor(d.hash)
    return hash
  }

  ** Equality is based on id and arguments
  override Bool equals(Obj? that)
  {
    m := that as HxMsg
    if (m == null) return false
    return id == m.id &&
            a == m.a  &&
            b == m.b  &&
            d == m.d  &&
            d == m.d
  }

  ** Return debug string representation
  override Str toStr()
  {
    Etc.debugMsg("HxMsg", id, a, b, c, d)
  }
}

