//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 May 2012  Brian Frank  Create
//

**
** MiscTest
**
class MiscTest : Test
{

  Void testCircularBuf()
  {
    c := CircularBuf(3)
    verifyEq(c.max, 3)
    verifyCircularBuf(c, Str[,])
    c.add("a"); verifyCircularBuf(c, ["a"])
    c.add("b"); verifyCircularBuf(c, ["b", "a"])
    c.add("c"); verifyCircularBuf(c, ["c", "b", "a"])
    c.add("d"); verifyCircularBuf(c, ["d", "c", "b"])
    c.add("e"); verifyCircularBuf(c, ["e", "d", "c"])
    c.add("f"); verifyCircularBuf(c, ["f", "e", "d"])
    c.add("g"); verifyCircularBuf(c, ["g", "f", "e"])

    c.resize(3)
    verifyCircularBuf(c, ["g", "f", "e"])
    c.resize(2)
    verifyCircularBuf(c, ["g", "f"])
    c.add("h"); verifyCircularBuf(c, ["h", "g"])
    c.add("i"); verifyCircularBuf(c, ["i", "h"])
    c.add("j"); verifyCircularBuf(c, ["j", "i"])
    c.add("k"); verifyCircularBuf(c, ["k", "j"])
    c.resize(4)
    verifyCircularBuf(c, ["k", "j"])
    c.add("l"); verifyCircularBuf(c, ["l", "k", "j"])
    c.add("m"); verifyCircularBuf(c, ["m", "l", "k", "j"])
    c.add("n"); verifyCircularBuf(c, ["n", "m", "l", "k"])
    c.add("o"); verifyCircularBuf(c, ["o", "n", "m", "l"])
    c.add("p"); verifyCircularBuf(c, ["p", "o", "n", "m"])
    c.add("q"); verifyCircularBuf(c, ["q", "p", "o", "n"])

    // eachWhile
    list := Str[,]
    c.eachWhile |v| { list.add(v); return v == "p" ? true : null }
    verifyEq(list, ["q", "p"])

    // eachrWhile
    list.clear
    c.eachrWhile |v| { list.add(v); return v == "p" ? true : null }
    verifyEq(list, ["n", "o", "p"])

    // clear
    c.clear
    verifyEq(c.max, 4)
    verifyCircularBuf(c, Str[,])
  }

  Void verifyCircularBuf(CircularBuf c, Obj?[] expected)
  {
    // each
    actual := Str[,]
    verifyEq(c.size, expected.size)
    c.each |val| { actual.add(val) }
    // echo("  ::: $actual ?= $expected  $c.newest | $c.oldest")
    verifyEq(actual, expected)

    verifyEq(c.newest, expected.first)
    verifyEq(c.oldest, expected.last)

    revActual := Str[,]
    revExpect := expected.dup.reverse
    c.eachr |val| { revActual.add(val) }
    // echo("      $revActual ?= $revExpect")
    verifyEq(revActual, revExpect)

  }

}