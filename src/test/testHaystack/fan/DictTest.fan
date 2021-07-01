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