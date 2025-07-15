//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2021  Matthew Giannini  Creation
//

using xeto
using haystack
using hx

**
** Docker image management
**
const class DockerExt : ExtObj
{
  new make()
  {
    mgr = DockerMgr(this)
  }

  ** Settings record
  override DockerSettings rec() { super.rec }

  ** Docker manager
  const DockerMgr mgr

  ** Stop callback
  override Void onStop()
  {
    mgr.shutdown
  }
}

**************************************************************************
** DockerSettings
**************************************************************************

const class DockerSettings : TypedDict
{
  ** Constructor
  new make(Dict d, |This|f) : super(d) { f(this) }

  ** Docker daemon URI to connect to. If unspecified, then the host default will be
  ** used.
  ** - 'npipe:////./pipe/docker_engine' (Windows named pipe)
  ** - 'unix:///var/run/docker.sock' (Unix domain socket)
  ** - 'tcp://localhost:2375' (TCP/HTTP access)
  @TypedTag { meta =
    Str<|placeholder: "<host default>"
        |>
  }
  const Str? dockerDaemon := null

  ** Experimental.
  **
  ** Explicitly indicate the io/ directory to mount for this project.
  @NoDoc @TypedTag { meta =
    Str<|placeholder: "<project default>"
        |>
  }
  const Str? ioDirMount := null
}

