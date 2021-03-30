//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Apr 2016  Brian Frank  Creation
//

** AuthErr
const class AuthErr : Err
{
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

