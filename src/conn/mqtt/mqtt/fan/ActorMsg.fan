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

  override Str toStr() { "ActorMsg($id, $a, $b, $c)" }
}