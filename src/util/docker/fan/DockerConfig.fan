//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Oct 2021  Matthew Giannini  Creation
//

using inet

const class DockerConfig
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This|? f := null)
  {
    f?.call(this)
  }

  private static const Str defUnixDaemonHost := "unix:///var/run/docker.sock"
  private static const Str defWinDaemonHost  := "npipe:////./pipe/docker_engine"

  private static Bool isWin() { Env.cur.os.contains("win") }

//////////////////////////////////////////////////////////////////////////
// Config
//////////////////////////////////////////////////////////////////////////

  ** The docker daemon Uri
  const Str daemonHost := isWin ? defWinDaemonHost : defUnixDaemonHost

  ** Version of the docker API to use
  const Version apiVer := Version("1.41")

  ** Registry username
  const Str? registryUsername

  ** Registry password
  const Str? registryPassword

  ** TCP socket configuration
  const SocketConfig socketConfig := SocketConfig.cur

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  Str? hostScheme() { daemonHost.toUri.scheme }

  AuthConfig authConfig()
  {
    AuthConfig(registryUsername, registryPassword)
  }
}