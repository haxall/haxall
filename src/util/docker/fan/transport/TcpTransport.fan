//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Oct 2021  Matthew Giannini  Creation
//

using inet

internal class TcpTransport : DockerTransport
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(DockerConfig config)
  {
    this.config = config
    uri := config.daemonHost.toUri
  }

  private const DockerConfig config

//////////////////////////////////////////////////////////////////////////
// DockerTransport
//////////////////////////////////////////////////////////////////////////

  override OutStream out()
  {
    throw IOErr("TODO")
  }

  override InStream in()
  {
    throw IOErr("TODO")
  }

  override Void close()
  {
    throw IOErr("TODO")
  }
}
