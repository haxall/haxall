//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Oct 2021  Matthew Giannini  Creation
//

class StopContainerCmd : DockerHttpCmd
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) : super(f)
  {
  }

  new makeId(Str id) : super.make(null)
  {
    this.id = id
  }

  ** The ID of name of the container
  Str id { private set }
  ** Set the `id` and return this
  This withId(Str id) { this.id = id; return this }

  ** Number of seconds to wait before killing the container
  Int? wait { private set }
  This withWait(Duration dur)
  {
    sec := dur.toSec
    if (sec < 0) throw ArgErr("$dur")
    this.wait = sec
    return this
  }

//////////////////////////////////////////////////////////////////////////
// DockerHttpCmd
//////////////////////////////////////////////////////////////////////////

  protected override Uri apiPath()
  {
    query := Str:Str[:]
    if (wait != null) query["t"] = wait.toStr
    return `/containers/${id}/stop`.plusQuery(query)
  }

  override StatusRes exec()
  {
    send |res->StatusRes|
    {
      switch (res.statusCode)
      {
        case 204: return StatusRes.noErr
        case 304: return StatusRes(res, "container already stopped")
        case 404: return StatusRes(res, "no such container")
        case 500: return StatusRes(res, "server error")
        default:  return StatusRes(res)
      }
    }
  }

}