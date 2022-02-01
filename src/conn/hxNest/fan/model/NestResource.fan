//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

**
** Base class for all Google Nest Resource types
**
abstract const class NestResource
{
  new make([Str:Obj?] json) { this.json = json }

  protected static const Unit celsius := Unit.fromStr("celsius")
  protected static const Unit relHum := Unit.fromStr("%RH")

  protected abstract Str traitsKey()

  const [Str:Obj?] json

  ** Get the full "name" of this resource. This is the relative
  ** path to the resource
  Uri name() { ((Str)json["name"]).toUri }

  ** The id or this particular resource. Typically this is the last
  ** value in the `name` path.
  virtual Str id() { name.path.last ?: "" }

  ** Custom name for this resource
  virtual Str dis() { traitVal("Info", "customName") }

  [Str:Obj?] traits() { json["traits"] }

  ** Get the trait map for the given trait
  Map trait(Str name) { traits["${traitsKey}.${name}"] }

  ** Get a trait field
  Obj? traitVal(Str trait, Str field) { this.trait(trait)[field] }

  override Str toStr() { json.toStr }
}