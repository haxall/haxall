//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Feb 2016  Brian Frank  Creation
//

const class StoreErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

const class UnknownBlobErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

const class ConcurrentWriteErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

