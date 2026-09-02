//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Sep 2026  Creation
//

using xeto

**
** Maps Xeto units and quantities to the QUDT vocabulary.
**
@NoDoc @Js
const class RdfQudtMap
{
  ** Load the mappings packaged by sys.rdf.
  static RdfQudtMap load()
  {
    lib := XetoEnv.cur.resolveNamespace(["sys.rdf"]).lib("sys.rdf")
    units := (Str:Str)lib.files.get(`/qudt-units.props`).read |in| { in.readProps }
    quantities := (Str:Str)lib.files.get(`/qudt-quantities.props`).read |in| { in.readProps }
    return make(units, quantities)
  }

  private new make(Str:Str units, Str:Str quantityProps)
  {
    quantities := Str:Str[][:]
    quantityProps.each |targets, name|
    {
      quantities[name] = targets.split(',').map |target->Str| { target.trim }.toImmutable
    }
    this.units = units.toImmutable
    this.quantities = quantities.toImmutable
  }

  ** Map a runtime unit, resolved from any accepted name or symbol, to QUDT.
  Str unit(Unit unit)
  {
    target := units[unit.name]
      ?: throw UnsupportedErr("No reviewed QUDT mapping for Xeto unit '${unit.name}'")
    quantity := UnitQuantity.unitToQuantity[unit]
      ?: throw UnsupportedErr("Xeto unit '${unit.name}' has no runtime quantity")
    prefix := quantity == UnitQuantity.currency ? "currency" : "unit"
    return "${prefix}:${target}"
  }

  ** Map one Xeto quantity to its accepted QUDT quantity-kind alternatives.
  Str[] quantity(UnitQuantity quantity)
  {
    quantities[quantity.name]
      ?: throw UnsupportedErr("No reviewed QUDT mapping for Xeto quantity '${quantity.name}'")
  }

  private const Str:Str units
  private const Str:Str[] quantities
}
