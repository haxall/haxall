//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Dec 2021  Brian Frank   Creation
//

using haystack
using axon
using hx

**
** HxCoreLibTest extends CoreLib tests for tests which use hx runtime.
** These tests do not run in JavaScript though
**
class HxCoreLibTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Defs
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testDefs()
  {
    verifyDefsInclude("defs()", ["elec", "elec-meter", "func:now"], [,])
    verifyDefsInclude("terms()", ["elec", "elec-meter"], ["func:now"])
    verifyDefsInclude("tags()", ["elec"], ["elec-meter", "func:now"])
    verifyDefsInclude("conjuncts()", ["elec-meter"], ["elec", "func:now"])
    verifyDefsInclude("libs()", ["lib:ph", "lib:hx"], ["elec", "elec-meter", "func:now"])

    verifyDefsEq("supertypes(^site)", ["geoPlace", "entity"])
    verifyDefsEq("inheritance(^site)", ["geoPlace", "entity", "marker", "site"])
    verifyDefsEq("inheritance(^ahu)", ["marker", "entity", "equip", "airHandlingEquip", "ahu", "air-output", "output", "elec-input", "input"])
    verifyDefsInclude("subtypes(^equip)", ["airHandlingEquip", "conduit", "chiller"], ["ahu", "duct"])
    verifyEq(eval("hasSubtypes(^equip)"), true)
    verifyEq(eval("hasSubtypes(^mau)"), false)

    verifyDefsInclude("associations(^site, ^tags)", ["id", "dis", "geoAddr", "geoCountry", "area"], ["unit"])

    verifyDefsEq("""reflect({chilled, water})""", ["chilled", "water", "chilled-water"])

    verifyDictsEq(eval("protos({equip})"), [["equip":m], ["point":m]])
  }

  Void verifyDefsEq(Str expr, Str[] syms)
  {
    g := (Def[])eval(expr)
    verifyEq(g.dup.sort.map |x->Str| { x.symbol.toStr }, syms.sort)
  }

  Void verifyDefsInclude(Str expr, Str[] has, Str[] missing)
  {
    g := (Def[])eval(expr)

    has.each |name|
    {
      row := g.find |r| { r->def.toStr == name }
      verifyNotNull(row, name)
      verifyDictEq(row, rt.ns.def(name))
    }

    missing.each |name|
    {
      row := g.find |r| { r->def.toStr == name }
      verifyNull(row, name)
    }
  }

}