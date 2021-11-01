//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2021  Matthew Giannini  Creation
//

**
** A Docker container
**
const class DockerContainer : DockerObj
{
  new make(|This| f) : super(f)
  {
  }

  ** The ID of this container
  const Str id

  ** The names that this container has been given
  const Str[] names

  ** The name of the image used when creating this container
  const Str image

  ** The ID of the image that this container was created from
  const Str imageID

  ** Command to run when starting this container
  const Str command

  ** When the container was created
  const Int created

  // TODO: Ports

  ** The size of files that have been created or changed by this container
  const Int? sizeRw

  ** The total size of all the files in this container
  const Int? sizeRootFs

  ** User-defined key/value metadata
  const Str:Str labels := [:]

  ** The state of this container(e.g. 'Exited')
  const Str state

  ** Additional human-readable status of this container (e.g. 'Exit 0')
  const Str status

  // TODO: HostConfig
  // TODO: NetworkSettings
  // TODO: Mounts

  ** Get the timestamp the container was created at
  DateTime createdAt(TimeZone tz := TimeZone.cur)
  {
    DockerUtil.unixSecToTs(created, tz)
  }

}