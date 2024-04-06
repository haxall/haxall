//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jan 2023  Brian Frank  Creation
//

using util
using xeto
using xeto::Dict
using haystack

**
** SpecTest
**
@Js
class SpecTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Meta
//////////////////////////////////////////////////////////////////////////

  Void testMeta()
  {
    lib := compileLib(
      Str<|Foo: Dict <a:"A", b:"B">
           Bar: Foo <b:"B2", c:"C"> { qux: Str <e:"E", f:"F"> "x" }
           Baz: Bar <c:"C2", d:"D"> { qux: Str <f:"F2", g:"G"> "y" }
           |>)

     // env.print(lib)

     obj := env.spec("sys::Obj")
     verifyEq(obj.get("base", "_"), "_")
     verifyEq(obj.has("base"), false)
     verifyEq(obj.missing("base"), true)
     verifyEq(obj.has("type"), false)
     verifyEq(obj.missing("type"), true)

     verifyMeta(obj, Str:Obj["sealed":m, "abstract":m],  Str:Obj["sealed":m, "abstract":m])
     verifyMeta(lib.type("Foo"), Str:Obj["a":"A", "b":"B"],  Str:Obj["a":"A", "b":"B"])
     verifyMeta(lib.type("Bar"), Str:Obj["b":"B2", "c":"C"],  Str:Obj["a":"A", "b":"B2", "c":"C"])
     verifyMeta(lib.type("Baz"), Str:Obj["c":"C2", "d":"D"],  Str:Obj["a":"A", "b":"B2", "c":"C2", "d":"D"])

     verifyMeta(lib.type("Bar").slot("qux"), Str:Obj["e":"E", "f":"F", "val":"x"],  Str:Obj["e":"E", "f":"F", "val":"x"])
     verifyMeta(lib.type("Baz").slot("qux"), Str:Obj["f":"F2", "g":"G", "val":"y"],  Str:Obj["e":"E", "f":"F2", "g":"G", "val":"y"])
  }

  Void verifyMeta(Spec s, Str:Obj own, Str:Obj effective)
  {
    verifyMetaDict(s.metaOwn, own)

    verifyMetaDict(s.meta, effective)

    // spec itself is effective meta + built-in tags
    self := effective.dup
    self["id"] = s._id
    self["spec"] = ref("sys::Spec")
    if (s.isType)
      self.addNotNull("base", s.base?._id)
    else
      self["type"] = s.type._id
    verifyMetaDict(s, self)
  }

  Void verifyMetaDict(Dict d, Str:Obj expect)
  {
    actual := Str:Obj[:]
    d.each |v, n|
    {
      if (n == "doc") return
      actual[n] = v
    }
    verifyValEq(actual, expect)

    expect.each |v, n|
    {
      verifyValEq(v, d.get(n))
      verifyValEq(v, d.trap(n))
      verifyEq(d.has(n), true)
      verifyEq(d.missing(n), false)
    }

    actual.clear
    firstName := null
    d.eachWhile |v, n|
    {
      if (n == "doc") return null
      if (firstName == null) firstName = n
      actual[n] = v
      return null
    }
    verifyValEq(actual, expect)

    actual.clear
    d.eachWhile |v, n|
    {
      if (n == "doc") return null
      actual[n] = v
      return "break"
    }
    verifyValEq(actual, Str:Obj[firstName: expect[firstName]])
  }

//////////////////////////////////////////////////////////////////////////
// Is-A
//////////////////////////////////////////////////////////////////////////

  Void testIsa()
  {
    // TODO
    // verifyAllEnvs("ph.points") |env| { doTestIsa }
    doTestIsa
  }

  Void doTestIsa()
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
    verifyIsa("sys::Func", "sys::Func",  true)
    verifyIsa("sys::Str",  "sys::Func",   false)

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

    verifyIsa("sys::And",   "sys::And",   true, false)
    verifyIsa("sys::Or",    "sys::Or",    true, false)

    // env.print(env.spec("ph.points::DischargeAirTempSensor"))

    verifyIsa("ph.points::AirFlowSensor", "sys::And", true)
    verifyIsa("ph.points::AirFlowSensor", "ph::Point", true)
    verifyIsa("ph.points::AirFlowSensor", "ph::Sensor", true)
    verifyIsa("ph.points::AirFlowSensor", "sys::Dict", true, false)

    verifyIsa("ph.points::ZoneAirTempSensor", "ph::Point", true)
    verifyIsa("ph.points::ZoneAirTempSensor", "sys::Dict", true, false)

    verifyIsa("ph::DuctSection",   "sys::Choice",    true)
    verifyIsa("ph::DischargeDuct", "sys::Choice",    true)
    verifyIsa("ph::Phenomenon",    "sys::Choice",    true)
    verifyIsa("ph::Fluid",         "sys::Choice",    true)
    verifyIsa("ph::Fluid",         "ph::Phenomenon", true)
    verifyIsa("ph::PipeFluid",     "sys::Choice",    true)
    verifyIsa("ph::PipeFluid",     "ph::Fluid",      true)
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
// Choice Of
//////////////////////////////////////////////////////////////////////////

  Void testChoiceOf()
  {
    verifyChoiceOf(["discharge":m], "ph::DuctSection", "ph::DischargeDuct")
    verifyChoiceOf(["foo":m], "ph::DuctSection", null)
    verifyChoiceOf(["elec":m], "ph::Phenomenon", "ph::Elec")
    verifyChoiceOf(["elec":m, "dc":m], "ph::Phenomenon", "ph::DcElec")
    verifyChoiceOf(["naturalGas":m], "ph::Phenomenon", "ph::NaturalGas")
    verifyChoiceOf(["naturalGas":m], "ph::Liquid", null)
    verifyChoiceOf(["water":m], "ph::Fluid", "ph::Water")
    verifyChoiceOf(["water":m, "hot":m], "ph::Fluid", "ph::HotWater")

    // TODO
    //verifyChoiceOf(["water":m, "hot":m, "naturalGas":m], "ph::Fluid", null)
  }

  Void verifyChoiceOf(Str:Obj tags, Str choice, Str? expect)
  {
    actual := env.choiceOf(dict(tags), env.spec(choice), false)
    //echo("--> $tags choiceOf $choice => $actual ?= $expect")
    verifyEq(actual?.qname, expect)
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
     foo := lib.type("Foo")
     qux := lib.type("Qux")

     bar := foo.slotOwn("bar")
     verifySame(bar.type, str)
     verifySame(bar["maybe"], m)
     verifyEq(bar.isa(str), true)
     verifyEq(bar.isMaybe, true)

     baz := foo.slotOwn("baz")
     verifySame(baz.type, foo)
     verifySame(baz["maybe"], m)
     verifyEq(baz.isa(foo), true)
     verifyEq(baz.isMaybe, true)

     // bar override with maybe
     qbar := qux.slot("bar")
     verifySame(qbar.base, bar)
     verifySame(qbar["maybe"], m)
     verifyEq(qbar.isa(str), true)
     verifyEq(qbar.isMaybe, true)

     // non-maybe type sets maybe to none
     qbaz := qux.slot("baz")
     verifySame(qbaz.base, baz)
     verifyEq(qbaz["maybe"], null)
     verifyEq(qbaz.metaOwn["maybe"], none)
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
     foo := lib.type("Foo")
     bar := lib.type("Bar")

     fooBar := lib.type("FooBar")
     verifySame(fooBar.type.base, and)
     verifyEq(fooBar.isa(and), true)
     verifyEq(fooBar.ofs, Spec[foo,bar])
     verifyEq(fooBar["ofs"], [foo._id, bar._id])
   }

//////////////////////////////////////////////////////////////////////////
// Reflection
//////////////////////////////////////////////////////////////////////////

  Void testReflection()
  {
    ph := env.lib("ph")
    phx := env.lib("ph.points")

    equipSlots := [
      "dis:Str?", "id:Ref", "equip:Marker",
      "equipRef:Ref?", "siteRef:Ref", "spaceRef:Ref?", "systemRef:Ref?",
      "points:Query"]
    meterSlots       := equipSlots.dup.addAll(["meter:Marker", "meterScope:MeterScope?", "submeterOf:Ref?"])
    elecMeterSlots   := meterSlots.dup.add("elec:Marker")
    acElecMeterSlots := elecMeterSlots.dup.addAll(["ac:Marker", "phaseCount:PhaseCount?"])

    verifySlots(ph.type("Equip"),       equipSlots)
    verifySlots(ph.type("Meter"),       meterSlots)
    verifySlots(ph.type("ElecMeter"),   elecMeterSlots)
    verifySlots(ph.type("AcElecMeter"), acElecMeterSlots)

    ptSlots := [
      "dis:Str?", "id:Ref",
      "point:Marker", "cur:Marker?", "enum:Obj?",
      "equipRef:Ref", "his:Marker?", "kind:Kind",
      "maxVal:Number?", "minVal:Number?",
      "pointFunction:PointFunction?", "pointQuantity:PointQuantity?", "pointSubject:PointSubject?",
      "siteRef:Ref", "spaceRef:Ref?", "systemRef:Ref?",
      "tz:TimeZone?", "unit:Unit?", "writable:Marker?",
      "equips:Query"]
    numPtSlots := ptSlots.dup.set(ptSlots.findIndex { it == "unit:Unit?"}, "unit:Unit")
    afSlots    := numPtSlots.dup.addAll(["air:Marker", "flow:Marker"])
    afsSlots   := afSlots.dup.add("sensor:Marker")
    dafsSlots  := afsSlots.dup.add("discharge:Marker")

    verifySlots(ph.type("Point"), ptSlots)
    verifySlots(phx.type("NumberPoint"), numPtSlots)
    verifySlots(phx.type("AirFlowPoint"), afSlots)
    verifySlots(phx.type("AirFlowSensor"), afsSlots)
    verifySlots(phx.type("DischargeAirFlowSensor"), dafsSlots)

    cond := phx.type("WeatherCondPoint")
    verifyEq(cond.slot("enum")["val"], haystack::Ref("ph::WeatherCondEnum"))

    eqA := env.spec("hx.test.xeto::EqA")
    a := eqA.slot("points").slot("a")
    verifyEq(a.slot("co2")["val"], Marker.val)
    verifyEq(a.slot("foo", false), null)
    b := eqA.slot("points").slot("b")
    verifyEq(b.slot("co2")["val"], Marker.val)
    verifyEq(b.slot("foo")["val"], Marker.val)
  }

  Void verifySlots(Spec t, Str[] expected)
  {
    slots := t.slots
    i := 0
    slots.each |s|
    {
      type := s.type.name
      if (s.isMaybe) type += "?"
      // echo("-- $s.name: $type $s.meta")
      verifyEq("$s.name:$type", expected[i++])
    }
    verifyEq(slots.names.size, expected.size)
  }

//////////////////////////////////////////////////////////////////////////
// Query Inherit
//////////////////////////////////////////////////////////////////////////

  Void testQueryInherit()
  {
    lib := compileLib(
      Str<|pragma: Lib < version: "0.0.0", depends: { { lib:"sys" }, { lib:"ph" } } >
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
    verifyQueryInherit(lib.type("AhuA"),  ["discharge-temp"])
    verifyQueryInherit(lib.type("AhuB"),  ["return-temp"])
    verifyQueryInherit(lib.type("AhuAB"), ["discharge-temp", "return-temp"])
    verifyQueryInherit(lib.type("AhuC"),  ["discharge-temp", "return-temp", "outside-temp"])

    // explicitly named
    verifyQueryInherit(lib.type("AhuX"),  ["dat:discharge-temp"])
    verifyQueryInherit(lib.type("AhuY"),  ["rat:return-temp"])
    verifyQueryInherit(lib.type("AhuXY"), ["dat:discharge-temp", "rat:return-temp"])
    verifyQueryInherit(lib.type("AhuZ"),  ["dat:discharge-temp", "rat:return-temp", "oat:outside-temp"])

    // extra testing for mergeInheritedSlots
    a:= lib.type("AhuA")
    aPts := a.slot("points")
    ab := lib.type("AhuAB")
    abPts := ab.slot("points")
    verifyEq(abPts.qname, "${lib.name}::AhuAB.points")
    verifyEq(abPts.type, env.type("sys::Query"))
    verifyEq(abPts.base, aPts)
  }

  Void verifyQueryInherit(Spec x, Str[] expectPoints)
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

