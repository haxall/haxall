//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

**
** A parent relation
**
const class ParentRelation
{
  new make(Map json)
  {
    this.parent = ((Str)json["parent"]).toUri
    this.dis    = json["displayName"]
  }

  ** The name of the relation -- e.g., structure/room where the device is assigned to
  const Uri parent

  ** The custom name of the relation -- e.g., structure/room where the device is assigned to.
  const Str dis

  override Str toStr() { "$dis [$parent]" }
}