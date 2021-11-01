//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Oct 2021  Matthew Giannini  Creation
//

**
** Ping the docker daemon
**
internal class PingCmd : DockerHttpCmd
{
  new make() : super.make(null) { }

  protected override Uri apiPath() { `/_ping` }

  protected override DockerHttpReqBuilder httpReq() { super.httpReq.withMethod("GET") }

  override DockerHttpRes exec() { super.exec }
}