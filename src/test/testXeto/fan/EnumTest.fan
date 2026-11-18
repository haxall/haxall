//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** EnumTest
**
@Js
class EnumTest : AbstractXetoTest
{

  Void testBasics()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileTempLib(
      Str<|// Cards
           Suit: Enum { diamonds, clubs, hearts, spades }
           |>)

     e := lib.spec("Suit")
    // env.print(e)

     verifyEq(e.isEnum, true)
     verifyEq(e.base.qname, "sys::Enum")
     verifyEq(e.base.isEnum, false)
     verifyEq(e.meta["sealed"], Marker.val)
     verifyEq(e.meta["val"], Scalar(e.qname, "diamonds"))
     verifySame(e.enum, e.enum)
     verifyEq(e.enum.keys, ["diamonds", "clubs", "hearts", "spades"])
     verifyEnumFlags(e)
     verifyEnumItem(e, "diamonds", ["doc":"Cards"])
     verifyEnumItem(e, "clubs",    ["doc":"Cards"])
     verifyEnumItem(e, "hearts",   ["doc":"Cards"])
     verifyEnumItem(e, "spades",   ["doc":"Cards"])

     // SpecEnum.each
     acc := Str:Spec?[:]
     e.enum.each |x, k| { acc[k] = x }
     verifyEq(acc, [
       "diamonds": e.slot("diamonds"),
       "clubs":    e.slot("clubs"),
       "hearts":   e.slot("hearts"),
       "spades":   e.slot("spades")])
  }

  Void testKeys()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileTempLib(
      Str<|// Cards
           Suit: Enum {
             diamonds <key:"Diamonds!">
             clubs    <key:"Clubs!">
             hearts   <key:"Hearts!">
             spades   <key:"Spades!">
           }
           |>)

     e := lib.spec("Suit")
     // env.print(e)

     verifyEq(e.isEnum, true)
     verifyEq(e.meta["sealed"], Marker.val)
     verifyEq(e.meta["val"], Scalar(e.qname, "Diamonds!"))
     verifySame(e.enum, e.enum)
     verifyEq(e.enum.keys, ["Diamonds!", "Clubs!", "Hearts!", "Spades!"])
     verifyEnumFlags(e)
     verifyEnumItem(e, "Diamonds!", ["key":"Diamonds!", "doc":"Cards"])
     verifyEnumItem(e, "Clubs!",    ["key":"Clubs!",    "doc":"Cards"])
     verifyEnumItem(e, "Hearts!",   ["key":"Hearts!",   "doc":"Cards"])
     verifyEnumItem(e, "Spades!",   ["key":"Spades!",   "doc":"Cards"])

     // SpecEnum.each
     acc := Str:Spec?[:]
     e.enum.each |x, k| { acc[k] = x }
     verifyEq(acc, [
       "Diamonds!": e.slot("diamonds"),
       "Clubs!":    e.slot("clubs"),
       "Hearts!":   e.slot("hearts"),
       "Spades!":   e.slot("spades")])
  }

  Void testMeta()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileTempLib(
      Str<|// Cards
           Suit: Enum <foo> {
             diamonds  <color:"r">  // Red diamonds
             clubs    <color:"b">  // Black clubs
             hearts   <color:"r">  // Red hearts
             spades   <color:"b">  // Black spades
           }
           +Spec {
             color: Str?
             foo: Marker?
           }
           |>)

     e := lib.spec("Suit")
     // env.print(e)

     verifyEq(e.isEnum, true)
     verifyEq(e.meta["foo"], Marker.val)
     verifyEq(e.meta["sealed"], Marker.val)
     verifyEq(e.meta["val"], Scalar(e.qname, "diamonds"))
     verifyEnumFlags(e)
     verifyEnumItem(e, "diamonds", ["foo":m, "color":"r", "doc":"Red diamonds"])
     verifyEnumItem(e, "clubs",    ["foo":m, "color":"b", "doc":"Black clubs"])
     verifyEnumItem(e, "hearts",   ["foo":m, "color":"r", "doc":"Red hearts"])
     verifyEnumItem(e, "spades",   ["foo":m, "color":"b", "doc":"Black spades"])
  }

  Void testInstances()
  {
    ns := createNamespace(["sys"])

    lib := ns.compileTempLib(
      Str<|Color: Enum { red, blue, green }
           Car: Dict { color: Color }
           @a: Car { color:"red" }
           @b: Car { color:"blue" }
           |>)

     e := lib.type("Color")
     c := lib.type("Car")
     a := lib.instance("a")
     b := lib.instance("b")
     verifyDictEq(a, ["id":Ref("${lib.name}::a"), "spec":c.id, "color":Scalar(e.qname, "red")])
     verifyDictEq(b, ["id":Ref("${lib.name}::b"), "spec":c.id, "color":Scalar(e.qname, "blue")])
  }

  Void verifyEnumFlags(Spec enum)
  {
    verifyEq(enum.isScalar, true)
    verifyEq(enum.isChoice, false)
    verifyEq(enum.isDict,   false)
    verifyEq(enum.isList,   false)
    verifyEq(enum.isGrid,   false)
    verifyEq(enum.isQuery,  false)
  }

  Void verifyEnumItem(Spec e, Str key, Str:Obj meta)
  {
    x := e.enum.spec(key)
    // echo("::::: $x $key base=$x.base type=$x.type $x.meta")
    verifySame(x.type, e)
    verifySame(x.parent, e)
    verifyEnumFlags(x)
    verifyDictEq(x.meta, meta)
  }

  Void testUnitQuantity()
  {
    ns := createNamespace

    fan  := UnitQuantity.vals.map |x->Str| { x.name }
    verifyEq(fan[0], "dimensionless")
    fan = fan[1..-1]

    // verify we keep fantom UnitQuanity in-sync with xeto definition
    xeto := ns.spec("sys::UnitQuantity").slots.names
    xeto.each |n, i|
    {
      verifyEq(n, fan.getSafe(i))
    }
    verifyEq(xeto.size, fan.size)

    u := ns.spec("sys::Unit.meter")
    verifyEq(u.meta["quantity"], UnitQuantity.length)
  }

  Void testPhPoints()
  {
    ns := createNamespace(["ph.points"])

    /*
    WeatherCondPoint : WeatherPoint & EnumPoint {
      weatherCond
      enum: Obj? <def:WeatherCondEnum>
    }

    OccupiedPoint : BoolPoint <abstract> {
      occupied
      enum: Obj? <val:OccupiedEnum>
    }

    OccupiedEnum : Enum { unoccupied, occupied }
    */

    cond := ns.spec("ph::WeatherCondEnum")
    condSlot := ns.spec("ph.points::WeatherCondPoint.enum")
    condVal := condSlot.meta.get("val")
    // echo("-- $condSlot | $condVal [$condVal.typeof]")
    verifyEq(condVal, cond.id)

    occ := ns.spec("ph.points::OccupiedEnum")
    occSlot := ns.spec("ph.points::OccupiedPoint.enum")
    occVal := occSlot.meta.get("val")
    // echo("-- $occSlot | $occVal [$occVal.typeof]")
    verifyEq(occVal, occ.id)
  }

//////////////////////////////////////////////////////////////////////////
// Fantom
//////////////////////////////////////////////////////////////////////////

  Void testFantom()
  {
    ns := createNamespace(["hx.test.xeto"])
    plain := ns.spec("hx.test.xeto::TestFanEnum")
    keyed := ns.spec("hx.test.xeto::TestFanKeyedEnum")

    // bindings
    verifyEq(plain.binding.typeof, EnumBinding#)
    verifyEq(plain.fantomType, TestFanEnum#)
    verifyEq(keyed.fantomType, TestFanKeyedEnum#)

    // every item of the spec is the Fantom item of the same name
    verifyFantomItems(plain, TestFanEnum.vals)
    verifyFantomItems(keyed, TestFanKeyedEnum.vals)

    // decode is by key; a name which is not a key is not a value
    verifyFantom(plain, "alpha",   TestFanEnum.alpha)
    verifyFantom(plain, "beta",    TestFanEnum.beta)
    verifyFantom(keyed, "default", TestFanKeyedEnum.def)
    verifyFantom(keyed, "icon-xs", TestFanKeyedEnum.iconXs)
    verifyFantom(keyed, "plain",   TestFanKeyedEnum.plain)
    verifyEq(keyed.binding.decodeScalar("def", false), null)
    verifyEq(keyed.binding.decodeScalar("iconXs", false), null)
    verifyEq(plain.binding.decodeScalar("gamma", false), null)
    verifyErr(ParseErr#) { keyed.binding.decodeScalar("iconXs") }

    // enum key
    verifyEq(XetoUtil.enumKey(TestFanEnum.beta), "beta")
    verifyEq(XetoUtil.enumKey(TestFanKeyedEnum.def), "default")
    verifyEq(XetoUtil.enumKey(TestFanKeyedEnum.iconXs), "icon-xs")
    verifyEq(XetoUtil.enumKey(TestFanKeyedEnum.plain), "plain")

    // instantiate
    verifySame(ns.instantiate(plain), TestFanEnum.alpha)
    verifySame(ns.instantiate(keyed), TestFanKeyedEnum.def)
    Dict d := ns.instantiate(ns.spec("hx.test.xeto::TestFanEnumSlots"))
    verifySame(d["a"], TestFanEnum.alpha)
    verifySame(d["b"], TestFanEnum.beta)
    verifySame(d["c"], TestFanKeyedEnum.def)
    verifySame(d["d"], TestFanKeyedEnum.iconXs)
    verifyEq(d["e"], null)

    // xeto and jeto io
    verifySame(ns.io.readXeto(Str<|hx.test.xeto::TestFanKeyedEnum "icon-xs"|>), TestFanKeyedEnum.iconXs)
    verifyEq(ns.io.writeXetoToStr(TestFanKeyedEnum.iconXs).contains(Str<|"icon-xs"|>), true)
    json := ns.io.writeJetoToStr(d)
    verifyEq(json.contains(Str<|"icon-xs"|>), true)
    verifyEq(json.contains("iconXs"), false)
    Dict r := ns.io.readJeto(json.in)
    verifySame(r["c"], TestFanKeyedEnum.def)
    verifySame(r["d"], TestFanKeyedEnum.iconXs)

    // validation
    slots := ns.spec("hx.test.xeto::TestFanEnumSlots")
    verifyEq(ns.validate(d, slots).items.size, 0)
    bad := ns.validate(Etc.dictSet(d, "d", Scalar(keyed.qname, "iconXs")), slots)
    verifyEq(bad.items.join(",") { it.rule.id.toStr }, "sys::wrongEnumKey")
  }

  private Void verifyFantom(Spec spec, Str key, Enum val)
  {
    verifySame(spec.binding.decodeScalar(key), val)
    verifyEq(spec.binding.encodeScalar(val), key)
    verifyEq(spec.enum.spec(key).name, val.name)
  }

  private Void verifyFantomItems(Spec spec, Enum[] vals)
  {
    names := Str[,]
    spec.enum.each |item, key| { names.add(item.name) }
    verifyEq(names, vals.map |v->Str| { v.name })
  }
}
**************************************************************************
** TestFanEnum
**************************************************************************

@Js
enum class TestFanEnum { alpha, beta }

**************************************************************************
** TestFanKeyedEnum
**************************************************************************

@Js
enum class TestFanKeyedEnum : KeyedEnum
{
  def("default"), iconXs("icon-xs"), plain

  private new make(Str? key := null) { this.key = key ?: name }

  override const Str key
}
