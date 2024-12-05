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
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
      Str<|a: Str <meta>
           b: Str <meta>
           c: Str <meta>
           d: Str <meta>
           e: Str <meta>
           f: Str <meta>
           g: Str <meta>

           Foo: Dict <a:"A", b:"B">
           Bar: Foo <b:"B2", c:"C"> { qux: Str <e:"E", f:"F"> "x" }
           Baz: Bar <c:"C2", d:"D"> { qux: Str <f:"F2", g:"G"> "y" }
           |>)

     // env.print(lib)

     obj := ns.spec("sys::Obj")
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
// XMeta
//////////////////////////////////////////////////////////////////////////

  Void testXMeta()
  {
    ns := createNamespace(["ph.points", "hx.test.xeto"])

    // Lib.hasXMeta flag
    verifyEq(ns.lib("sys").hasXMeta, false)
    verifyEq(ns.lib("ph").hasXMeta, false)
    verifyEq(ns.lib("hx.test.xeto").hasXMeta, true)

    // Site (normal spec)
    spec := ns.spec("ph::Site")
    doc := spec.meta["doc"]
    verifyXMeta(ns, spec,
      ["doc":doc],
      ["doc":doc, "foo":"building"])

    // area (global spec)
    spec = ns.spec("ph::area")
    doc = spec.meta["doc"]
    verifyXMeta(ns, spec,
      ["doc":doc, "val":n(0), "quantity":UnitQuantity.area],
      ["doc":doc, "val":n(0), "quantity":UnitQuantity.area, "foo":"AreaEditor", "bar":"hello"])

    // Vav (inherited from Equip)
    spec = ns.spec("ph::Vav")
    doc = spec.meta["doc"]
    verifyXMeta(ns, spec,
      ["doc":doc],
      ["doc":doc, "qux":"Device"])
  }

  Void verifyXMeta(LibNamespace ns, Spec spec, Str:Obj meta, Str:Obj xmeta)
  {
    actual := ns.xmeta(spec.qname)
    verifyDictEq(spec.meta, meta)
    verifyDictEq(actual, xmeta)
  }

//////////////////////////////////////////////////////////////////////////
// XMeta Enum
//////////////////////////////////////////////////////////////////////////

  Void testXMetaEnum()
  {
    ns := createNamespace(["ph", "hx.test.xeto"])
    verifyEq(ns.lib("hx.test.xeto").hasXMeta, true)

    spec := ns.spec("ph::CurStatus")
    verifyErr(UnsupportedErr#) { spec.enum.xmeta }
    verifyErr(UnsupportedErr#) { spec.enum.xmeta("ok") }

    e := ns.xmetaEnum("ph::CurStatus")

    doc := spec.meta["doc"]
    verifyDictEq(e.xmeta, Etc.dictToMap(spec.meta).set("qux", "_self_"))
    verifyDictEq(e.xmeta("ok"), Etc.dictToMap(e.spec("ok").meta).set("color", "green"))
    verifyDictEq(e.xmeta("down"), Etc.dictToMap(e.spec("down").meta).set("color", "yellow"))
    verifyDictEq(e.xmeta("disabled"), e.spec("disabled").meta)

    // test ph::EnumLine where names are different than keys
    e = ns.xmetaEnum("ph::ElecLine")
    verifyDictEq(e.xmeta("L1"), Etc.dictToMap(e.spec("L1").meta).set("foo", "Line 1"))
  }

//////////////////////////////////////////////////////////////////////////
// Is-A
//////////////////////////////////////////////////////////////////////////

  Void testIsa()
  {
    verifyLocalAndRemote(["ph.points"]) |ns| { doTestIsa(ns) }
  }

  Void doTestIsa(LibNamespace ns)
  {
    verifyIsa(ns, "sys::Obj", "sys::Obj", true)
    verifyIsa(ns, "sys::Obj", "sys::Str", false)

    verifyIsa(ns, "sys::None", "sys::Obj",    true)
    verifyIsa(ns, "sys::None", "sys::None",   true)
    verifyIsa(ns, "sys::None", "sys::Scalar", true)
    verifyIsa(ns, "sys::None", "sys::Dict",   false)

    verifyIsa(ns, "sys::Scalar", "sys::Obj",    true)
    verifyIsa(ns, "sys::Scalar", "sys::Scalar", true)
    verifyIsa(ns, "sys::Scalar", "sys::Str",    false)

    verifyIsa(ns, "sys::Marker", "sys::Scalar", true)

    verifyIsa(ns, "sys::Ref", "sys::Scalar", true)
    verifyIsa(ns, "sys::Ref", "sys::Ref", true)

    verifyIsa(ns, "sys::MultiRef", "sys::Obj", true)
    verifyIsa(ns, "sys::MultiRef", "sys::Ref", false)
    verifyIsa(ns, "sys::MultiRef", "sys::MultiRef", true)

    verifyIsa(ns, "sys::Str", "sys::Obj",    true)
    verifyIsa(ns, "sys::Str", "sys::Scalar", true)
    verifyIsa(ns, "sys::Str", "sys::Str",    true)
    verifyIsa(ns, "sys::Str", "sys::Int",    false)
    verifyIsa(ns, "sys::Str", "sys::Dict",   false)
    verifyIsa(ns, "sys::Str", "sys::And",    false)
    verifyIsa(ns, "sys::Func", "sys::Func",  true)
    verifyIsa(ns, "sys::Str",  "sys::Func",   false)

    verifyIsa(ns, "sys::Int", "sys::Obj",    true)
    verifyIsa(ns, "sys::Int", "sys::Scalar", true)
    verifyIsa(ns, "sys::Int", "sys::Number", true)
    verifyIsa(ns, "sys::Int", "sys::Int",    true)
    verifyIsa(ns, "sys::Int", "sys::Duration",false)

    verifyIsa(ns, "sys::Seq", "sys::Seq",  true)
    verifyIsa(ns, "sys::Seq", "sys::Dict", false)

    verifyIsa(ns, "sys::Dict", "sys::Seq",  true)
    verifyIsa(ns, "sys::Dict", "sys::Dict", true)
    verifyIsa(ns, "sys::Dict", "sys::List", false)

    verifyIsa(ns, "sys::List", "sys::Seq",  true)
    verifyIsa(ns, "sys::List", "sys::List", true)
    verifyIsa(ns, "sys::List", "sys::Dict", false)

    verifyIsa(ns, "sys::And",   "sys::And",   true, false)
    verifyIsa(ns, "sys::Or",    "sys::Or",    true, false)

    // env.print(env.spec("ph.points::DischargeAirTempSensor"))

    s := verifyIsa(ns, "ph.points::AirFlowSensor", "sys::And", true)
    verifyIsa(ns, "ph.points::AirFlowSensor", "ph::Point", true)
    verifyIsa(ns, "ph.points::AirFlowSensor", "ph::Sensor", true)
    verifyIsa(ns, "ph.points::AirFlowSensor", "sys::Dict", true, false)
    verifyEq(s.isAnd, true)

    s = verifyIsa(ns, "ph.points::AirTempSensor", "ph.points::AirTempPoint", true)
    s = verifyIsa(ns, "ph.points::AirTempSensor", "ph::Point", true)
    verifyEq(s.isAnd, true)

    s = verifyIsa(ns, "ph.points::ZoneAirTempSensor", "ph::Point", true)
    verifyIsa(ns, "ph.points::ZoneAirTempSensor", "ph.points::AirTempPoint", true)
    verifyIsa(ns, "ph.points::ZoneAirTempSensor", "ph.points::AirTempSensor", true)
    verifyIsa(ns, "ph.points::ZoneAirTempSensor", "sys::Dict", true, false)
    verifyEq(s.isAnd, false)

    verifyIsa(ns, "ph::DuctSection",   "sys::Choice",    true)
    verifyIsa(ns, "ph::DischargeDuct", "sys::Choice",    true)
    verifyIsa(ns, "ph::Phenomenon",    "sys::Choice",    true)
    verifyIsa(ns, "ph::Fluid",         "sys::Choice",    true)
    verifyIsa(ns, "ph::Fluid",         "ph::Phenomenon", true)
    verifyIsa(ns, "ph::PipeFluid",     "sys::Choice",    true)
    verifyIsa(ns, "ph::PipeFluid",     "ph::Fluid",      true)
  }

  Spec verifyIsa(LibNamespace ns, Str an, Str bn, Bool expect, Bool expectMethod := expect)
  {
    a := ns.type(an)
    b := ns.type(bn)
    m := a.typeof.method("is${b.name}", false)
    isa := a.isa(b)
    // echo("-> $a isa $b = $isa ?= $expect [$m]")
    verifyEq(isa, expect)
    if (m != null) verifyEq(m.call(a), expectMethod)
    return a
  }

//////////////////////////////////////////////////////////////////////////
// Maybe
//////////////////////////////////////////////////////////////////////////

  Void testMaybe()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
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

     str := ns.type("sys::Str")
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
    ns := createNamespace(["sys"])

    lib := ns.compileLib(
      Str<|Foo: Dict
           Bar: Dict
           FooBar : Foo & Bar
           |>)

     //env.print(lib)

     and := ns.type("sys::And")
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
    ns := createNamespace(["ph.points", "hx.test.xeto"])
    ph := ns.lib("ph")
    phx := ns.lib("ph.points")

    equipSlots := [
      "id:Ref", "equip:Marker",
      "equipRef:Ref?", "siteRef:Ref", "spaceRef:Ref?", "systemRef:MultiRef?",
      "parentEquips:Query", "childEquips:Query", "points:Query"]
    meterSlots       := equipSlots.dup.addAll(["meter:Marker", "meterScope:MeterScope?", "submeterOf:Ref?"])
    elecMeterSlots   := meterSlots.dup.add("elec:Marker")
    acElecMeterSlots := elecMeterSlots.dup.addAll(["ac:Marker", "phaseCount:PhaseCount?"])

    verifySlots(ph.type("Equip"),       equipSlots)
    verifySlots(ph.type("Meter"),       meterSlots)
    verifySlots(ph.type("ElecMeter"),   elecMeterSlots)
    verifySlots(ph.type("AcElecMeter"), acElecMeterSlots)

    ptSlots := [
      "id:Ref",
      "point:Marker", "cur:Marker?", "enum:Obj?",
      "equipRef:Ref?", "his:Marker?", "kind:Kind",
      "maxVal:Number?", "minVal:Number?",
      "pointFunction:PointFunction?", "pointQuantity:PointQuantity?", "pointSubject:PointSubject?",
      "siteRef:Ref?", "spaceRef:Ref?", "systemRef:MultiRef?",
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

    eqA := ns.spec("hx.test.xeto::EqA")
    a := eqA.slot("points").slot("a")
    verifyEq(a.slot("co2")["val"], Marker.val)
    verifyEq(a.slot("foo", false), null)
    b := eqA.slot("points").slot("b")
    verifyEq(b.slot("co2")["val"], Marker.val)
    verifyEq(b.slot("foo")["val"], "!")
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
    ns := createNamespace(["ph"])
    lib := ns.compileLib(
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
    verifyQueryInherit(ns, lib.type("AhuA"),  ["discharge-temp"])
    verifyQueryInherit(ns, lib.type("AhuB"),  ["return-temp"])
    verifyQueryInherit(ns, lib.type("AhuAB"), ["discharge-temp", "return-temp"])
    verifyQueryInherit(ns, lib.type("AhuC"),  ["discharge-temp", "return-temp", "outside-temp"])

    // explicitly named
    verifyQueryInherit(ns, lib.type("AhuX"),  ["dat:discharge-temp"])
    verifyQueryInherit(ns, lib.type("AhuY"),  ["rat:return-temp"])
    verifyQueryInherit(ns, lib.type("AhuXY"), ["dat:discharge-temp", "rat:return-temp"])
    verifyQueryInherit(ns, lib.type("AhuZ"),  ["dat:discharge-temp", "rat:return-temp", "oat:outside-temp"])

    // extra testing for mergeInheritedSlots
    a:= lib.type("AhuA")
    aPts := a.slot("points")
    ab := lib.type("AhuAB")
    abPts := ab.slot("points")
    verifyEq(abPts.qname, "${lib.name}::AhuAB.points")
    verifySame(abPts.type, ns.type("sys::Query"))
    verifyEq(abPts.base, aPts)
  }

  Void verifyQueryInherit(LibNamespace ns, Spec x, Str[] expectPoints)
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
    verifyEq(q.type, ns.spec("sys::Query"))
    verifyEq(actualPoints, expectPoints)
  }

}

