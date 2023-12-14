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
           Suit: Enum { diamond, clubs, hearts, spades }
           |>)

     e := lib.top("Suit")
     // env.print(e)

     verifyEq(e.isEnum, true)
     verifyEq(e.meta["sealed"], Marker.val)
     verifyEnumFlags(e)
     verifyEnumItem(e, "diamond", ["doc":"Cards"])
     verifyEnumItem(e, "clubs",   ["doc":"Cards"])
     verifyEnumItem(e, "hearts",  ["doc":"Cards"])
     verifyEnumItem(e, "spades",  ["doc":"Cards"])
  }

  Void testMeta()
  {
    lib := compileLib(
      Str<|// Cards
           Suit: Enum <foo> {
             diamond  <color:"r">  // Red diamonds
             clubs    <color:"b">  // Black clubs
             hearts   <color:"r">  // Red hearts
             spades   <color:"b">  // Black spades
           }
           |>)

     e := lib.top("Suit")
     // env.print(e)

     verifyEq(e.isEnum, true)
     verifyEq(e.meta["foo"], Marker.val)
     verifyEnumFlags(e)
     verifyEnumItem(e, "diamond", ["foo":m, "color":"r", "doc":"Red diamonds"])
     verifyEnumItem(e, "clubs",   ["foo":m, "color":"b", "doc":"Black clubs"])
     verifyEnumItem(e, "hearts",  ["foo":m, "color":"r", "doc":"Red hearts"])
     verifyEnumItem(e, "spades",  ["foo":m, "color":"b", "doc":"Black spades"])
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
    verifyEq(enum.isSeq,    false)
    verifyEq(enum.isDict,   false)
    verifyEq(enum.isList,   false)
    verifyEq(enum.isQuery,  false)
  }

  Void verifyEnumItem(Spec enum, Str name, Str:Obj meta)
  {
    x := enum.slot(name)
    // echo("::::: $x base=$x.base type=$x.type $x.meta")
    verifySame(x.type, enum)
    verifyEnumFlags(x)
    verifyDictEq(x.meta, meta)
  }
}