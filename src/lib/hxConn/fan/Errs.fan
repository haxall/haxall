//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Dec 2021  Brian Frank  Creation
//

@NoDoc
const class UnknownConnErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

