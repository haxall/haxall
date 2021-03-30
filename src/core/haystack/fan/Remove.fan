//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Jan 2010  Brian Frank  Creation
//

**
** Remove is the singleton which indicates a remove operation.
**
@Js
const final class Remove
{
  ** Singleton value
  const static Remove val := Remove()

  private new make() {}

  ** Return "remove"
  override Str toStr() { "remove" }
}