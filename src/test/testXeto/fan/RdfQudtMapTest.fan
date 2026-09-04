//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Sep 2026  Creation
//

using xeto
using xetom

** RdfQudtMapTest
@Js
class RdfQudtMapTest : Test
{
  Void testLookup()
  {
    map := RdfQudtMap.load
    verifyEq(map.unit(Unit.fromStr("°F")), "unit:DEG_F")
    verifyEq(map.unit(Unit.fromStr("\$")), "currency:USD")
    verifyEq(map.quantity(UnitQuantity.temperature), ["Temperature"])
    verifyEq(map.quantity(UnitQuantity.energy), ["Energy", "MomentOfForce", "Torque"])

    verifyErrMsg(UnsupportedErr#,
      "No reviewed QUDT mapping for Xeto unit 'centum_cubic_feet_natural_gas'")
    {
      map.unit(Unit.fromStr("Ccf_natural_gas"))
    }
  }

  Void testSources()
  {
    map := RdfQudtMap.load
    lib := XetoEnv.cur.resolveNamespace(["sys.rdf"]).lib("sys.rdf")
    units := readProps(lib, `/qudt-units.props`)
    quantities := readProps(lib, `/qudt-quantities.props`)

    units.each |target, name|
    {
      unit := Unit.fromStr(name, false)
      verifyNotNull(unit, "Unknown canonical Xeto unit: $name")
      verifyEq(unit.name, name)
      verifyQudtNames(name, [target])
      quantity := UnitQuantity.unitToQuantity[unit]
      verifyNotNull(quantity, "Xeto unit has no runtime quantity: $name")
      prefix := quantity == UnitQuantity.currency ? "currency" : "unit"
      verifyEq(map.unit(unit), "${prefix}:${target}")
    }

    quantities.each |targets, name|
    {
      quantity := UnitQuantity.fromStr(name, false)
      verifyNotNull(quantity, "Unknown Xeto quantity: $name")
      names := targets.split(',').map |target->Str| { target.trim }
      verify(!names.isEmpty, "No QUDT targets for $name")
      verify(names.all |Str target->Bool| { !target.isEmpty }, "Empty QUDT target for $name")
      verifyEq(names.unique.size, names.size, "Duplicate QUDT target for $name")
      verifyQudtNames(name, names)
      verifyEq(map.quantity(quantity), names)
    }
  }

  private Str:Str readProps(Lib lib, Uri uri)
  {
    return (Str:Str)lib.files.get(uri).read |in| { in.readProps }
  }

  private Void verifyQudtNames(Str xetoName, Str[] qudtNames)
  {
    qudtNames.each |qudtName|
    {
      verify(qudtLocalName.matches(qudtName),
        "Invalid QUDT target '$qudtName' for '$xetoName'")
    }
  }

  private static const Regex qudtLocalName := Regex<|[A-Za-z_][A-Za-z0-9._-]*|>
}
