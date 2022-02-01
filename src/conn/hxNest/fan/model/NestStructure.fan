//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

const class NestStructure : NestResource
{
  new make(Map json) : super(json)
  {
  }

  override protected const Str traitsKey := "sdm.structures.traits"
}

const class NestRoom : NestResource
{
  new make(Map json) : super(json)
  {
  }

  override protected const Str traitsKey := "sdm.structures.traits"

  override Str dis() { traitVal("RoomInfo", "customName") }

  ** Get the id of the structure this room is in
  **   enterprises/<project-id>/structures/<structure-id>/rooms/<room-id>
  Str structureId() { name.path[3] }
}