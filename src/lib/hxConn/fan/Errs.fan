//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Dec 2021  Brian Frank  Creation
//


** Models a failure condition when the remote point is not "ok"
const class RemoteStatusErr : Err
{
  ** Construct with status of remote point
  new make(ConnStatus status) : super(status.name)
  {
    if (status.isOk) throw ArgErr("RemoteStatusErr cannot be 'ok'")
    this.status = status
  }

  ** Status of the remote point
  const ConnStatus status
}

@NoDoc
const class UnknownConnErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

@NoDoc
const class UnknownConnPointErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}