//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Oct 2021  Matthew Giannini  Creation
//

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

  const Str daemonHost := isWin ? defWinDaemonHost : defUnixDaemonHost

  const Version apiVer := Version("1.41")

  const Str? registryUsername

  const Str? registryPassword

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  Str? hostScheme() { daemonHost.toUri.scheme }

  AuthConfig authConfig()
  {
    AuthConfig(registryUsername, registryPassword)
  }
}