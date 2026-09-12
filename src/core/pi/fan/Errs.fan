//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 May 2024  Brian Frank  Creation
//

@NoDoc @Js
const class UnknownItemErr : Err
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause) {}
}

