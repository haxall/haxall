//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Oct 2021  Matthew Giannini  Creation
//

**
** DockerClient provides conveniences for creating commands to
** communicate with the Docker daemon. All commands are initially
** configured based on the `DockerConfig` used to construct the client.
**
class DockerClient
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(DockerConfig config)
  {
    this.config = config
  }

  const DockerConfig config

//////////////////////////////////////////////////////////////////////////
// DockerClient
//////////////////////////////////////////////////////////////////////////

  Bool ping()
  {
    PingCmd(config).exec.statusCode == 200
  }

  PullImageCmd pullImage(Str repo)
  {
    PullImageCmd(config, repo)
  }

  ListImagesCmd listImages()
  {
    ListImagesCmd(config)
  }

  CreateContainerCmd createContainer(Str image)
  {
    CreateContainerCmd(config).withImage(image)
  }

  StartContainerCmd startContainer(Str id)
  {
    StartContainerCmd(config, id)
  }

  StopContainerCmd stopContainer(Str id)
  {
    StopContainerCmd(config, id)
  }

  ListContainersCmd listContainers()
  {
    ListContainersCmd(config)
  }

  RemoveContainerCmd removeContainer(Str id)
  {
    RemoveContainerCmd(config, id)
  }

}