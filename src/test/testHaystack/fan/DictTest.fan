//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jun 2021  Brian Frank  Create
//

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

  Void testTypedDict()
  {
    x := TypedDictTest(Etc.emptyDict)
    verifyEq(x.int, 99)
    verifyEq(x.num, n(99))
    verifyEq(x.dur, 99sec)
    verifyEq(x.bool, false)
    verifyEq(x.isEmpty, true)
    verifyEq(x.has("int"), false)
    verifyEq(x.missing("int"), true)
    verifyEq(x["int"], null)
    verifyErr(UnknownNameErr#) { x->int }

    x = TypedDictTest(Etc.makeDict4("int", n(3), "num", n(4, "kW"), "dur", n(5, "hr"), "bool", m))
    verifyEq(x.int, 3)
    verifyEq(x.num, n(4, "kW"))
    verifyEq(x.dur, 5hr)
    verifyEq(x.bool, true)
    verifyEq(x.isEmpty, false)
    verifyEq(x.has("int"), true)
    verifyEq(x.missing("int"), false)
    verifyEq(x["int"], n(3))
    verifyEq(x->int, n(3))
    verifyEq(Etc.dictToMap(x), Str:Obj?["int":n(3), "num":n(4, "kW"), "dur":n(5, "hr"), "bool":m])

    errs := Str[,]
    onErr := |Str e| { errs.add(e) }
    x = TypedDictTest(Etc.makeDict4("int", "bad", "num", "bad", "dur", n(5), "bool", true), onErr)
    // echo(errs.join("\n"))
    verifyEq(errs.size, 3)
    verifyEq(x.int, 99)
    verifyEq(x.num, n(99))
    verifyEq(x.dur, 99sec)
    verifyEq(x.bool, true)
    verifyEq(x.isEmpty, false)
    verifyEq(x.has("int"), true)
    verifyEq(x.missing("int"), false)
    verifyEq(x["int"], "bad")
    verifyEq(x->int, "bad")
  }

}

@Js
internal const class TypedDictTest : TypedDict
{
  static new wrap(Dict d, |Str|? onErr := null) { create(TypedDictTest#, d, onErr) }
  new make(Dict d, |This| f) : super(d) { f(this) }
  @TypedTag const Int int := 99
  @TypedTag const Number num := Number(99)
  @TypedTag const Duration dur := 99sec
  @TypedTag const Bool bool
}