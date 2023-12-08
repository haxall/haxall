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

**
** EnumTest
**
@Js
class EnumTest : AbstractXetoTest
{

  Void testBasics()
  {
    lib := compileLib(
      Str<|Suit: Enum { diamond, clubs, hearts, spades }
           |>)

     e := lib.top("Suit")
     //env.print(e)

     verifyEq(e.isEnum, true)
     verifyEnumFlags(e)
     verifyEnumItem(e, "diamond")
  }

  Void verifyEnumFlags(Spec enum)
  {
    verifyEq(enum.isScalar, true)
    verifyEq(enum.isSeq,    false)
    verifyEq(enum.isDict,   false)
    verifyEq(enum.isList,   false)
    verifyEq(enum.isQuery,  false)
  }

  Void verifyEnumItem(Spec enum, Str name)
  {
    x := enum.slot(name)
    //echo("::::: $x base=$x.base type=$x.type")
    verifySame(x.type, enum)
    verifyEnumFlags(x)
  }
}