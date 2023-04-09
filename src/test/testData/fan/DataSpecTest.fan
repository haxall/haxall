//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jan 2023  Brian Frank  Creation
//

using util
using data

**
** DataSpecTest
**
@Js
class DataSpecTest : AbstractDataTest
{

//////////////////////////////////////////////////////////////////////////
// Meta
//////////////////////////////////////////////////////////////////////////

  Void testMeta()
  {
    lib := compileLib(
      Str<|Foo: Dict <a:"A", b:"B">
           Bar: Foo <b:"B2", c:"C">
           Baz: Bar <c:"C2", d:"D">
           |>)

     // env.print(lib)

     verifyMeta(lib.slotOwn("Foo"), Str:Obj["a":"A", "b":"B"],  Str:Obj["a":"A", "b":"B"])
     verifyMeta(lib.slotOwn("Bar"), Str:Obj["b":"B2", "c":"C"],  Str:Obj["a":"A", "b":"B2", "c":"C"])
  }

  Void verifyMeta(DataSpec s, Str:Obj own, Str:Obj effective)
  {
    acc := Str:Obj[:]
    s.own.each |v, n| { acc[n] = v }
    verifyEq(acc, own)

    acc = Str:Obj[:]
    s.each |v, n| { acc[n] = v }
    acc.remove("doc")
    verifyEq(acc, effective)
  }

//////////////////////////////////////////////////////////////////////////
// Is-A
//////////////////////////////////////////////////////////////////////////

  Void testIsa()
  {
    verifyIsa("sys::Obj", "sys::Obj", true)
    verifyIsa("sys::Obj", "sys::Str", false)

    verifyIsa("sys::None", "sys::Obj",    true)
    verifyIsa("sys::None", "sys::None",   true)
    verifyIsa("sys::None", "sys::Scalar", true)
    verifyIsa("sys::None", "sys::Dict",   false)

    verifyIsa("sys::Scalar", "sys::Obj",    true)
    verifyIsa("sys::Scalar", "sys::Scalar", true)
    verifyIsa("sys::Scalar", "sys::Str",    false)

    verifyIsa("sys::Str", "sys::Obj",    true)
    verifyIsa("sys::Str", "sys::Scalar", true)
    verifyIsa("sys::Str", "sys::Str",    true)
    verifyIsa("sys::Str", "sys::Int",    false)
    verifyIsa("sys::Str", "sys::Dict",   false)
    verifyIsa("sys::Str", "sys::And",    false)

    verifyIsa("sys::Int", "sys::Obj",    true)
    verifyIsa("sys::Int", "sys::Scalar", true)
    verifyIsa("sys::Int", "sys::Number", true)
    verifyIsa("sys::Int", "sys::Int",    true)
    verifyIsa("sys::Int", "sys::Duration",false)

    verifyIsa("sys::Seq", "sys::Seq",  true)
    verifyIsa("sys::Seq", "sys::Dict", false)

    verifyIsa("sys::Dict", "sys::Seq",  true)
    verifyIsa("sys::Dict", "sys::Dict", true)
    verifyIsa("sys::Dict", "sys::List", false)

    verifyIsa("sys::List", "sys::Seq",  true)
    verifyIsa("sys::List", "sys::List", true)
    verifyIsa("sys::List", "sys::Dict", false)

    verifyIsa("sys::And",   "sys::And",   true)
    verifyIsa("sys::Or",    "sys::Or",    true)

    verifyIsa("ph.points::AirFlowSensor", "sys::And", true)
    verifyIsa("ph.points::AirFlowSensor", "ph::Point", true)
    verifyIsa("ph.points::AirFlowSensor", "ph.points::Sensor", true)
    verifyIsa("ph.points::AirFlowSensor", "sys::Dict", true, false)

    verifyIsa("ph.points::ZoneAirTempSensor", "ph::Point", true)
    verifyIsa("ph.points::ZoneAirTempSensor", "sys::Dict", true, false)
  }

  Void verifyIsa(Str an, Str bn, Bool expect, Bool expectMethod := expect)
  {
    a := env.type(an)
    b := env.type(bn)
    m := a.typeof.method("is${b.name}", false)
    isa := a.isa(b)
    // echo("-> $a isa $b = $isa ?= $expect [$m]")
    verifyEq(isa, expect)
    if (m != null) verifyEq(m.call(a), expectMethod)
  }

//////////////////////////////////////////////////////////////////////////
// Maybe
//////////////////////////////////////////////////////////////////////////

  Void testMaybe()
  {
    lib := compileLib(
      Str<|Foo: Dict {
             bar: Str?
             baz: Foo?
           }

           Qux: Foo {
             bar: Str?
             baz: Foo
           }
           |>)

     // env.print(lib)

     str := env.type("sys::Str")
     foo := lib.slotOwn("Foo")
     qux := lib.slotOwn("Qux")

     bar := foo.slotOwn("bar")
     verifySame(bar.type, str)
     verifySame(bar["maybe"], env.marker)
     verifyEq(bar.isa(str), true)
     verifyEq(bar.isMaybe, true)

     baz := foo.slotOwn("baz")
     verifySame(baz.type, foo)
     verifySame(baz["maybe"], env.marker)
     verifyEq(baz.isa(foo), true)
     verifyEq(baz.isMaybe, true)

     // bar override with maybe
     qbar := qux.slot("bar")
     verifySame(qbar.base, bar)
     verifySame(qbar["maybe"], env.marker)
     verifyEq(qbar.isa(str), true)
     verifyEq(qbar.isMaybe, true)

     // non-maybe type sets maybe to none
     qbaz := qux.slot("baz")
     verifySame(qbaz.base, baz)
     verifyEq(qbaz["maybe"], null)
     verifyEq(qbaz.own["maybe"], env.none)
     verifyEq(qbaz.isMaybe, false)
   }

//////////////////////////////////////////////////////////////////////////
// And
//////////////////////////////////////////////////////////////////////////

  Void testAnd()
  {
    lib := compileLib(
      Str<|Foo: Dict
           Bar: Dict
           FooBar : Foo & Bar
           |>)

     //env.print(lib)

     and := env.type("sys::And")
     foo := lib.slotOwn("Foo")
     bar := lib.slotOwn("Bar")

     fooBar := lib.slotOwn("FooBar")
     verifySame(fooBar.type.base, and)
     verifyEq(fooBar.isa(and), true)
     verifyEq(fooBar["ofs"], DataSpec[foo,bar])
   }

//////////////////////////////////////////////////////////////////////////
// Reflection
//////////////////////////////////////////////////////////////////////////

  Void testReflection()
  {
    ph := env.lib("ph")
    phx := env.lib("ph.points")

    equipSlots       := ["equip:Marker", "points:Query"]
    meterSlots       := equipSlots.dup.add("meter:Marker")
    elecMeterSlots   := meterSlots.dup.add("elec:Marker")
    acElecMeterSlots := elecMeterSlots.dup.add("ac:Marker")

    verifySlots(ph.slot("Equip"),       equipSlots)
    verifySlots(ph.slot("Meter"),       meterSlots)
    verifySlots(ph.slot("ElecMeter"),   elecMeterSlots)
    verifySlots(ph.slot("AcElecMeter"), acElecMeterSlots)

    ptSlots    := ["point:Marker", "equips:Query"]
    numPtSlots := ptSlots.dup.addAll(["kind:Str", "unit:Str"])
    afSlots    := numPtSlots.dup.addAll(["air:Marker", "flow:Marker"])
    afsSlots   := afSlots.dup.add("sensor:Marker")
    dafsSlots  := afsSlots.dup.add("discharge:Marker")
    verifySlots(ph.slot("Point"), ptSlots)
    verifySlots(phx.slot("NumberPoint"), numPtSlots)
    verifySlots(phx.slot("AirFlowPoint"), afSlots)
    verifySlots(phx.slot("AirFlowSensor"), afsSlots)
    verifySlots(phx.slot("DischargeAirFlowSensor"), dafsSlots)
  }

  Void verifySlots(DataSpec t, Str[] expected)
  {
    slots := t.slots
    i := 0
    slots.each |s|
    {
      verifyEq("$s.name:$s.type.name", expected[i++])
    }
    verifyEq(slots.names.size, expected.size)
  }

//////////////////////////////////////////////////////////////////////////
// Query Inherit
//////////////////////////////////////////////////////////////////////////

  Void testQueryInherit()
  {
    lib := compileLib(
      Str<|pragma: Lib < depends: { { lib:"sys" }, { lib:"ph" } } >
           AhuA: Equip {
             points: {
               { discharge, temp }
             }
           }
           AhuB: Equip {
             points: {
               { return, temp }
             }
           }

           AhuAB: AhuA & AhuB

           AhuC: AhuAB {
             points: {
               { outside, temp }
             }
           }

           AhuX: Equip {
             points: {
               dat: { discharge, temp }
             }
           }
           AhuY : Equip {
             points: {
               rat: { return, temp }
             }
           }

           AhuXY: AhuX & AhuY

           AhuZ: AhuXY {
             points: {
               oat: { outside, temp }
             }
           }
           |>)



    // env.print(env.genAst(lib), Env.cur.out, env.dict1("json", m))
    // env.print(lib, Env.cur.out, env.dict1("effective", m))

    // auto named
    verifyQueryInherit(lib.libType("AhuA"),  ["discharge-temp"])
    verifyQueryInherit(lib.libType("AhuB"),  ["return-temp"])
    verifyQueryInherit(lib.libType("AhuAB"), ["discharge-temp", "return-temp"])
    verifyQueryInherit(lib.libType("AhuC"),  ["discharge-temp", "return-temp", "outside-temp"])

    // explicitly named
    verifyQueryInherit(lib.libType("AhuX"),  ["dat:discharge-temp"])
    verifyQueryInherit(lib.libType("AhuY"),  ["rat:return-temp"])
    verifyQueryInherit(lib.libType("AhuXY"), ["dat:discharge-temp", "rat:return-temp"])
    verifyQueryInherit(lib.libType("AhuZ"),  ["dat:discharge-temp", "rat:return-temp", "oat:outside-temp"])

    // extra testing for mergeInheritedSlots
    a:= lib.libType("AhuA")
    aPts := a.slot("points")
    ab := lib.libType("AhuAB")
    abPts := ab.slot("points")
    verifyEq(abPts.qname, "${lib.qname}::AhuAB.points")
    verifyEq(abPts.type, env.type("sys::Query"))
    verifyEq(abPts.base, aPts)
  }

  Void verifyQueryInherit(DataSpec x, Str[] expectPoints)
  {
    q := x.slot("points")
    actualPoints := Str[,]
    q.slots.each |slot|
    {
      // env.print(slot, Env.cur.out, env.dict1("effective", m))
      sb := StrBuf()
      slot.slots.each |tag| { sb.join(tag.name, "-") }
      s := sb.toStr
      if (!slot.name.startsWith("_")) s = "$slot.name:$s"
      actualPoints.add(s)
    }
    // echo(">>> $q: $q.type")
    // echo("    $actualPoints")
    verifyEq(q.isQuery, true)
    verifyEq(q.type, env.spec("sys::Query"))
    verifyEq(actualPoints, expectPoints)
  }

}

