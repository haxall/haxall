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
  new makeConfig(DockerConfig config) : super(config)
  {
  }

  protected override Uri apiPath() { `/_ping` }

  protected override HttpReqBuilder httpReq() { super.httpReq.withMethod("GET") }

  override HttpRes exec() { super.exec }
}