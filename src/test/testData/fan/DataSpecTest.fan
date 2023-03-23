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

    verifyIsa("sys::None", "sys::Obj", true)
    verifyIsa("sys::None", "sys::None", true)
    verifyIsa("sys::None", "sys::Scalar", false)

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
             baz: Foo
           }
           |>)

    //env.print(lib)

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

     verifySame(qux.slot("bar"), bar)

     // do not inherit maybe
     qbaz := qux.slot("baz")
     verifySame(qbaz.base, baz)
     verifyEq(qbaz["maybe"], null)
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
           AhuA: {
             points: {
               { discharge, temp}
             }
           }
           AhuB: {
             points: {
               { return, temp}
             }
           }

           AhuAB: AhuA & AhuB

           AhuC: AhuAB {
             points: {
               { outside, temp}
             }
           }
           |>)

     // env.print(lib)

     verifyQueryInherit(lib.libType("AhuA"),  ["discharge-temp"])
     verifyQueryInherit(lib.libType("AhuB"),  ["return-temp"])
     verifyQueryInherit(lib.libType("AhuAB"), ["discharge-temp", "return-temp"])
     verifyQueryInherit(lib.libType("AhuC"),  ["discharge-temp", "return-temp", "outside-temp"])
  }

  Void verifyQueryInherit(DataSpec x, Str[] expectPoints)
  {
    q := x.slot("points")
    actualPoints := Str[,]
    q.slots.each |slot|
    {
      s := StrBuf()
      slot.slots.each |tag| { s.join(tag.name, "-") }
      actualPoints.add(s.toStr)
    }
    // echo(">>> $q: $q.type")
    // echo("    $actualPoints")
    verifyEq(q.isQuery, true)
    verifyEq(q.type, env.spec("sys::Query"))
    verifyEq(actualPoints, expectPoints)
  }

}

