//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Oct 2021  Matthew Giannini  Creation
//

**************************************************************************
** DockerErr
**************************************************************************

**
** General Docker Err
**
const class DockerErr : Err
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause)
  {
  }
}

**************************************************************************
** DockerResErr
**************************************************************************

**
** Docker command response error
**
const class DockerResErr : DockerErr
{
  new make(HttpRes res)
    : super(((Map)res.readJson)["message"] ?: "${res.statusCode}: ${res.statusMsg}")
  {
    this.res = StatusRes(res)
  }

  new makeCode(Int statusCode, Str msg)
    : super.make("$statusCode: $msg")
  {
    this.res = StatusRes(statusCode, msg)
  }

  const StatusRes res
}