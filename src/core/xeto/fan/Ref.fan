//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    3 Jan 2009  Brian Frank  Creation
//   17 Sep 2012  Brian Frank  Rework RecId -> Ref
//    8 Jul 2023  Brian Frank  Split base class into xeto
//

using concurrent

**
** Ref is used to model an entity identifier and optional display string.
**
@Js
abstract const class Ref
{
  ** Identifier that does **not** include leading '@' nor display string
  abstract Str id()

  ** Return display value of target if available, otherwise `id`
  abstract Str dis()

}