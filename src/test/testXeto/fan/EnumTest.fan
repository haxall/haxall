//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using haystack
using haystack::Ref

**
** EnumTest
**
@Js
class EnumTest : AbstractXetoTest
{

  Void testBasics()
  {
    lib := compileLib(
      Str<|// Cards
           Suit: Enum { diamonds, clubs, hearts, spades }
           |>)

     e := lib.top("Suit")
    // env.print(e)

     verifyEq(e.isEnum, true)
     verifyEq(e.meta["sealed"], Marker.val)
     verifyEq(e.meta["val"], "diamonds")
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
    lib := compileLib(
      Str<|// Cards
           Suit: Enum {
             diamonds <key:"Diamonds!">
             clubs    <key:"Clubs!">
             hearts   <key:"Hearts!">
             spades   <key:"Spades!">
           }
           |>)

     e := lib.top("Suit")
     // env.print(e)

     verifyEq(e.isEnum, true)
     verifyEq(e.meta["sealed"], Marker.val)
     verifyEq(e.meta["val"], "Diamonds!")
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
    lib := compileLib(
      Str<|// Cards
           Suit: Enum <foo> {
             diamonds  <color:"r">  // Red diamonds
             clubs    <color:"b">  // Black clubs
             hearts   <color:"r">  // Red hearts
             spades   <color:"b">  // Black spades
           }
           |>)

     e := lib.top("Suit")
     // env.print(e)

     verifyEq(e.isEnum, true)
     verifyEq(e.meta["foo"], Marker.val)
     verifyEq(e.meta["sealed"], Marker.val)
     verifyEq(e.meta["val"], "diamonds")
     verifyEnumFlags(e)
     verifyEnumItem(e, "diamonds", ["foo":m, "color":"r", "doc":"Red diamonds"])
     verifyEnumItem(e, "clubs",    ["foo":m, "color":"b", "doc":"Black clubs"])
     verifyEnumItem(e, "hearts",   ["foo":m, "color":"r", "doc":"Red hearts"])
     verifyEnumItem(e, "spades",   ["foo":m, "color":"b", "doc":"Black spades"])
  }

  Void testInstances()
  {
    lib := compileLib(
      Str<|Color: Enum { red, blue, green }
           Car: Dict { color: Color }
           @a: Car { color:"red" }
           @b: Car { color:"blue" }
           |>)

     e := lib.type("Color")
     c := lib.type("Car")
     a := lib.instance("a")
     b := lib.instance("b")
     verifyDictEq(a, ["id":Ref("${lib.name}::a"), "spec":c._id, "color":"red"])
     verifyDictEq(b, ["id":Ref("${lib.name}::b"), "spec":c._id, "color":"blue"])
  }

  Void verifyEnumFlags(Spec enum)
  {
    verifyEq(enum.isScalar, true)
    verifyEq(enum.isChoice, false)
    verifyEq(enum.isDict,   false)
    verifyEq(enum.isList,   false)
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
}