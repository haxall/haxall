//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Oct 2021  Matthew Giannini  Creation
//

**************************************************************************
** CreateContainerCmd
**************************************************************************

class CreateContainerCmd : DockerJsonCmd
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This|? f:= null) : super(f)
  {
  }

  ** Pattern for valid container names
  private static const Regex nameRegex := Regex <|/?[a-zA-Z0-9][a-zA-Z0-9_.-]+|>

//////////////////////////////////////////////////////////////////////////
// DockerJsonCmd
//////////////////////////////////////////////////////////////////////////

  ** Assign the specified name to the container.
  @JsonIgnore
  private Str? name { private set }
  ** Set the `name` and return this
  This withName(Str? name)
  {
    if (name != null && !nameRegex.matches(name)) throw ArgErr("Invalid name: ${name}")
    this.name = name
    return this
  }

  protected override Uri apiPath()
  {
    query := Str:Str[:]
    if (name != null) query["name"] = name
    return `/containers/create`.plusQuery(query)
  }

  override CreateContainerRes exec() { super.exec }

//////////////////////////////////////////////////////////////////////////
// JSON Properties
//////////////////////////////////////////////////////////////////////////

  ** The ports to expose in the container
  ExposedPorts? exposedPorts { private set }
  ** Set the `exposedPorts` and return this
  This withExposedPorts(ExposedPort[] ports) { this.exposedPorts = ExposedPorts(ports); return this}

  ** Command to run
  Str[]? cmd { private set }
  ** Set the `cmd` and return this
  This withCmd(Str[] cmd) { this.cmd = cmd; return this }

  ** The name of the image to use when creating the container
  Str? image { private set }
  ** Set the `image` and return this
  This withImage(Str image) { this.image = image; return this }

  ** Container configuration that depends on the host we are running on
  HostConfig? hostConfig { private set }
  ** Set the `hostConfig` and return this
  This withHostConfig(HostConfig hostConfig) { this.hostConfig = hostConfig; return this }
}

**************************************************************************
** CreateContainerRes
**************************************************************************

const class CreateContainerRes : DockerObj
{
  new make(|This| f) : super(f)
  {
  }

  ** The ID of the created container
  const Str id

  ** Warnings encountered when creating the container
  const Str[] warnings

  override Str toStr() { id }
}