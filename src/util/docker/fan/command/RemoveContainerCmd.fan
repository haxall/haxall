//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Oct 2021  Matthew Giannini  Creation
//

class RemoveContainerCmd : DockerHttpCmd
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) : super(f)
  {
  }

  new makeId(Str id) : this.makeConfig(null, id)
  {
  }

  new makeConfig(DockerConfig? config, Str id) : super(config)
  {
    this.id = id
  }

  ** The ID or name of the container
  Str id { private set }
  ** Set the `id` and return this
  This withId(Str id) { this.id = id; return this }

  ** Remove anonymous volumes associated with the container
  Bool removeAnonymousVolumes := false { private set }
  ** Set `removeAnonVolumes` and return this
  This withRemoveAnonymousVolumes(Bool v) { this.removeAnonymousVolumes = v; return this }

  ** If the container is running, kill it before removing it
  Bool force := false { private set }
  ** Set `force` and return this
  This withForce(Bool force) { this.force = force; return this}

  ** Remove the specified link associated with the container
  Bool link := false { private set }
  ** Set `link` and return this
  This withLink(Bool link) { this.link = link; return this }

//////////////////////////////////////////////////////////////////////////
// DockerHttpCmd
//////////////////////////////////////////////////////////////////////////

  protected override Uri apiPath()
  {
    Str:Str query := [:]
    if (removeAnonymousVolumes) query["v"] = "true"
    if (force) query["force"] = "true"
    if (link) query["link"] = "true"
    return `/containers/${id}`.plusQuery(query)
  }

  protected override HttpReqBuilder httpReq()
  {
    super.httpReq.withMethod("DELETE")
  }

  override StatusRes exec()
  {
    send |res->StatusRes|
    {
      switch (res.statusCode)
      {
        case 204: return StatusRes.noErr
        case 400: return StatusRes(res, "bad parameter")
        case 404: return StatusRes(res, "no such container")
        case 409: return StatusRes(res, "conflict")
        case 500: return StatusRes(res, "server error")
        default:  return StatusRes(res)
      }
    }
  }
}