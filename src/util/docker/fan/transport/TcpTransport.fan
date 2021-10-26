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
    uri  := config.daemonHost.toUri
    addr := IpAddr(uri.host)
    port := uri.port ?: 2375
    this.socket = TcpSocket(config.socketConfig).connect(addr, port)
  }

  private const DockerConfig config
  private TcpSocket socket

//////////////////////////////////////////////////////////////////////////
// DockerTransport
//////////////////////////////////////////////////////////////////////////

  override OutStream out()
  {
    socket.out
  }

  override InStream in()
  {
    socket.in
  }

  override Void close()
  {
    socket.close
  }
}
