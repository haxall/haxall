//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** GlobalSlotTest
**
@Js
class GlobalSlotTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
      Str<|// Person global slot marker
           person: Marker <xTest>

           // Global meta
           xTest: Marker <meta>

           // Person spec
           Person: Dict {
             person
             xTest:Str
           }
           |>)

     marker := ns.spec("sys::Marker")
     str    := ns.spec("sys::Str")

     g     := lib.spec("person")
     x     := lib.spec("xTest")
     t     := lib.spec("Person")
     slotm := t.slot("person")
     slotx := t.slot("xTest")

     // Lib.top lookups
     verifyEq(lib.specs, Spec[t, g, x])
     verifyEq(lib.specs.isImmutable, true)
     verifyEq(lib.spec("Bad", false), null)
     verifyErr(UnknownSpecErr#) { lib.spec("Bad") }
     verifyErr(UnknownSpecErr#) { lib.spec("bad", true) }

     // Lib.global lookups
     verifyEq(g.isType, false)
     verifyEq(g.isGlobal, true)
     verifyEq(g.isMeta, false)
     verifyEq(lib.globals, Spec[g, x])
     verifyEq(lib.globals.isImmutable, true)
     verifyEq(g.base, marker)
     verifyEq(g.type, marker)
     verifySame(lib.global("person"), g)
     verifyEq(lib.type("person", false), null)
     verifyErr(UnknownSpecErr#) { lib.type("person") }
     verifyErr(UnknownSpecErr#) { lib.type("person", true) }

     // Lib.global meta lookups
     verifyEq(x.isType, false)
     verifyEq(x.isGlobal, true)
     verifyEq(x.isMeta, true)
     verifyEq(x.base, marker)
     verifyEq(x.type, marker)
     verifySame(lib.global("xTest"), x)
     verifyEq(lib.type("xTest", false), null)
     verifyErr(UnknownSpecErr#) { lib.type("xTest") }
     verifyErr(UnknownSpecErr#) { lib.type("xTest", true) }

     // Lib.type lookups
     verifyEq(t.isType, true)
     verifyEq(t.isGlobal, false)
     verifyEq(t.isMeta, false)
     verifyEq(lib.types, Spec[t])
     verifyEq(lib.types.isImmutable, true)
     verifySame(lib.type("Person"), t)
     verifyErr(UnknownSpecErr#) { lib.global("Person") }
     verifyErr(UnknownSpecErr#) { lib.global("Person", true) }

     // verify Person.person is derived from global person
     verifySame(slotm.base, g)
     verifySame(slotm.type, marker)
     verifyEq(slotm.meta["doc"], "Person global slot marker")
     verifyEq(slotm.meta["xTest"], Marker.val)

     // verify Person.xMeta is **not** derived from global meta xTest
     verifySame(slotx.base, str)
     verifySame(slotx.type, str)
     verifyEq(slotx.meta["doc"], "Unicode string of characters")
  }

//////////////////////////////////////////////////////////////////////////
// Inheritance
//////////////////////////////////////////////////////////////////////////

  Void testInheritance()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
      Str<|a: Str <foo> "alpha"
           b: Date <bar> "2023-12-03"
           c: Marker <foo, bar>

           Baz: Dict {
             a: Str
             b: Date <baz>
             c
           }

           Qux: Baz {
             b: Date <qux> "2024-01-01"
           }

           Rux: Qux {
             c: Marker <rux>
           }

           foo: Marker <meta>
           bar: Marker <meta>
           baz: Marker <meta>
           qux: Marker <meta>
           rux: Marker <meta>
           |>)

     str    := ns.spec("sys::Str")
     date   := ns.spec("sys::Date")
     marker := ns.spec("sys::Marker")

     a := verifyGlobal(lib.global("a"), str,    ["foo":m, "val":"alpha"])
     b := verifyGlobal(lib.global("b"), date,   ["bar":m, "val":Date("2023-12-03")])
     c := verifyGlobal(lib.global("c"), marker, ["foo":m, "bar":m])

     baz := lib.type("Baz")
     qux := lib.type("Qux")
     rux := lib.type("Rux")

     verifyEq(a.base, str)
     verifyEq(a.type, str)

     //dumpBases(baz)
     //dumpBases(qux)
     //dumpBases(rux)

     // Baz
     bazA := verifySlot(baz, "a", a, str,    ["foo":m, "val":"alpha"])
     bazB := verifySlot(baz, "b", b, date,   ["bar":m, "val":Date("2023-12-03")])
     bazC := verifySlot(baz, "c", c, marker, ["foo":m, "bar":m])

     // Qux
     quxA := verifySlot(qux, "a", a,    str,    ["foo":m, "val":"alpha"])
     quxB := verifySlot(qux, "b", bazB, date,   ["bar":m, "val":Date("2024-01-01"), "qux":m])
     quxC := verifySlot(qux, "c", c,    marker, ["foo":m, "bar":m])
     verifySame(quxA, bazA)
     verifySame(quxC, bazC)

     // Rux
     ruxA := verifySlot(rux, "a", a,    str,    ["foo":m, "val":"alpha"])
     ruxB := verifySlot(rux, "b", bazB, date,   ["bar":m, "val":Date("2024-01-01"), "qux":m])
     ruxC := verifySlot(rux, "c", quxC, marker, ["foo":m, "bar":m, "rux":m])
     verifySame(ruxA, bazA)
     verifySame(ruxB, quxB)
  }

//////////////////////////////////////////////////////////////////////////
// PH
//////////////////////////////////////////////////////////////////////////

  Void testPh()
  {
    ns := createNamespace(["sys", "ph"])

    lib := ns.compileLib(
      Str<|pragma: Lib < version: "0.0.0", depends: { { lib:"sys" }, { lib:"ph" } } >

           Foo: Dict {
             zone
             space
             area: Number
           }
           |>)

     ph := ns.lib("ph")

     marker := ns.spec("sys::Marker")
     number := ns.spec("sys::Number")

     zone  := verifyGlobal(ph.global("zone"),  marker, null)
     space := verifyGlobal(ph.global("space"), marker, null)
     area  := verifyGlobal(ph.global("area"),  number, null)

     foo := lib.type("Foo")
     // env.print(foo)

    verifySlot(foo, "zone",  zone,  marker)
    verifySlot(foo, "space", space, marker)
    verifySlot(foo, "area",  area,  number)

  }

//////////////////////////////////////////////////////////////////////////
// Constrained Queries
//////////////////////////////////////////////////////////////////////////

  Void testConstrainedQueries()
  {
    // we want to verify that constrained query slots don't use global slots

    ns := createNamespace(["sys", "ph", "ph.points"])
    lib := ns.compileLib(
      Str<|pragma: Lib < version: "0.0.0", depends: { { lib:"sys" }, { lib:"ph" }, { lib:"ph.points" } } >

           Foo: Equip {
             ahu
             points: {
               discharge: DischargeAirTempSensor
               return: {return, air, temp, sensor, point}
             }
           }
           |>)

     dict := ns.spec("sys::Dict")
     dat := ns.spec("ph.points::DischargeAirTempSensor")

     foo := lib.type("Foo")
     // env.print(foo)

     pts := foo.slot("points")
     verifySame(pts.base, ns.spec("ph::Equip.points"))

     verifySlot(pts, "discharge", dat, dat)
     verifySlot(pts, "return",   dict, dict)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Spec verifyGlobal(Spec global, Spec type, [Str:Obj]? meta)
  {
    verifySame(global.type, type)
    verifySame(global.base, type)
    if (meta != null)
    {
      verifyDictEq(global.metaOwn, meta)
      meta.each |v, n| { verifyEq(global.meta[n], v) }
    }
    return global
  }

  Spec verifySlot(Spec parent, Str name, Spec base, Spec type, Str:Obj meta := [:])
  {
    slot := parent.slot(name)
    verifySame(slot.base, base)
    verifySame(slot.type, type)
    meta.each |v, n| { verifyEq(slot.meta[n], v) }
    return slot
  }

  Void dumpBases(Spec spec)
  {
    echo
    echo("-- $spec.qname")
    spec.slots.each |s|
    {
      echo("  $s.name base=$s.base type=$s.type meta=$s.meta")
    }
  }
}

