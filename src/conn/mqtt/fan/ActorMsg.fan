//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  05 Apr 2021   Matthew Giannini  Creation
//

**
** Actor Message
**
internal const class ActorMsg
{
  new make(Str id, Obj? a := null, Obj? b := null, Obj? c := null)
  {
    this.id = id
    this.a  = a
    this.b  = b
    this.c  = c
  }

  const Str id
  const Obj? a
  const Obj? b
  const Obj? c

  ** Hash is based on id and arguments
  override Int hash()
  {
    hash := id.hash
    if (a != null) hash = hash.xor(a.hash)
    if (b != null) hash = hash.xor(b.hash)
    if (c != null) hash = hash.xor(c.hash)
    return hash
  }

  ** Equality is based on id and arguments
  override Bool equals(Obj? that)
  {
    m := that as ActorMsg
    if (m == null) return false
    return id == m.id &&
            a == m.a  &&
            b == m.b  &&
            c == m.c
  }

  override Str toStr() { "ActorMsg($id, $a, $b, $c)" }
}