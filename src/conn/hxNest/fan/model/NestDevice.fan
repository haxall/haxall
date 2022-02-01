//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

**
** Google Nest Device
**
const class NestDevice : NestResource
{
  ** Get a strongly typed device type based on the json, or return
  ** a basic NestDevice as fallback.
  static NestDevice fromJson(Map json)
  {
    switch (json["type"])
    {
      case "sdm.devices.types.THERMOSTAT": return NestThermostat(json)
      default: return NestDevice(json)
    }
  }

  new make(Map json) : super.make(json)
  {
  }

  override protected const Str traitsKey := "sdm.devices.traits"

  ** Get the fully qualifed device type
  Str type() { json["type"] }

  ** Get the simple name of the type
  Str typeName()  { type.split('.').last }

  ** Get the parent relations
  ParentRelation[] parentRelations()
  {
    (json["parentRelations"] as List).map |p->ParentRelation| { ParentRelation(p) }
  }
}