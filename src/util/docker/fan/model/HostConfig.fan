//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Oct 2021  Matthew Giannini  Creation
//

class HostConfig
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This|? f:= null)
  {
    f?.call(this)
  }

//////////////////////////////////////////////////////////////////////////
// HostConfig
//////////////////////////////////////////////////////////////////////////

  ** Memory limit in bytes
  Int memory := 0 { private set }
  ** Set the `memory` and return this
  This withMemory(Int bytes) { this.memory = bytes.max(0); return this }

  ** Volume bindings for the container
  Bind[]? binds { private set }
  ** Set the `binds` and return this. Overwrites any existing binds.
  This withBinds(Bind[] binds) { this.binds = binds; return this }
  ** Add a volume binding and return this
  This withBind(Bind bind)
  {
    if (this.binds == null) binds = Bind[,]
    binds.add(bind)
    return this
  }

  ** The mapping of container ports to host ports.
  [ExposedPort:PortBinding[]]? portBindings { private set }
  ** Add port binding and return this
  This withPortBinding(ExposedPort container, PortBinding host)
  {
    if (portBindings == null) portBindings = [:] { ordered = true }
    portBindings.getOrAdd(container) |->PortBinding[]| { PortBinding[,] }.add(host)
    return this
  }

  ** Network mode to use for this container. Supported standard values are:
  ** 'bridge', 'host', 'none', and 'container:<name|id>'. Any other value is taken
  ** as a custom network's name to which this container should connect to.
  Str? networkMode { private set }
  ** Set the `networkMode` and return this
  This withNetworkMode(Str networkMode) { this.networkMode = networkMode; return this }
}