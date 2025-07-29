//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jun 2021  Brian Frank  Create
//

using xeto
using haystack

**
** DictTest
**
@Js
class DictTest : HaystackTest
{
  Void testMap()
  {
    verifyMap(Etc.dict0)
    verifyMap(Etc.dict1("one", n(1)))
    verifyMap(Etc.dict2("one", n(1), "two", n(2)))
    verifyMap(Etc.dict3("one", n(1), "two", n(2), "three", n(3)))
    verifyMap(Etc.dict4("one", n(1), "two", n(2), "three", n(3), "four", n(4)))
    verifyMap(Etc.dict5("one", n(1), "two", n(2), "three", n(3), "four", n(4), "five", n(5)))
    verifyMap(Etc.dict6("one", n(1), "two", n(2), "three", n(3), "four", n(4), "five", n(5), "six", n(6)))
    verifyMap(Etc.makeDict(["a":n(1), "b":n(2), "c":n(3), "d":n(4), "e":n(5), "f":n(6), "g":n(7)]))
  }

  Void verifyMap(Dict a)
  {
    b := a.map |v| { (Number)v + n(100) }
    // echo("---> $a [$a.typeof]")
    // echo("   > $b [$b.typeof]")
    a.each |v, k| { verifyEq(b[k], (Number)v + n(100)) }
  }

}

