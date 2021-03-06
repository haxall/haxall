//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2021  Matthew Giannini  Creation
//

using util

class PullImageCmd : DockerHttpCmd
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) : super(f)
  {
  }

  new makeRepo(Str repository) : super.make(null)
  {
    this.repository = repository
  }

  Str repository { private set }

  // TODO: AuthConfig

//////////////////////////////////////////////////////////////////////////
// DockerHttpCmd
//////////////////////////////////////////////////////////////////////////

  protected override Uri apiPath()
  {
    query := Str:Str[:]
    query["fromImage"] = repository
    query["tag"] = "latest"
    return `/images/create`.plusQuery(query)
  }

  protected override DockerHttpReqBuilder httpReq()
  {
    super.httpReq.withHeader("X-Registry-Auth", dockerConfig.authConfig.encode)
  }

  override DockerHttpRes exec()
  {
    send |res->DockerHttpRes|
    {
      while (true)
      {
        line := res.content.readLine
        if (line == null) break
        echo("###")
        echo(line)
      }
      return res
    }
  }
}
