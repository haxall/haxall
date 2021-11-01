//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Oct 2021  Matthew Giannini  Creation
//

**
** A Docker image.
**
const class DockerImage : DockerObj
{
  new make(|This| f) : super(f)
  {
  }

  const Str id

  const Str parentId

  const Str[] repoTags

  const Str[] repoDigests

  ** Seconds since Unix epoch
  const Int created

  const Int size

  const Int sharedSize

  const Int virtualSize

  const Str:Str labels

  const Int containers

  ** Get the timestamp the image was created at
  DateTime createdAt(TimeZone tz := TimeZone.cur)
  {
    DockerUtil.unixSecToTs(created, tz)
  }
}