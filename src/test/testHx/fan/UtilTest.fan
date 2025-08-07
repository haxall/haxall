//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack
using hx

**
** WatchTest
**
class UtilTest : HxTest
{

  Void testProjName()
  {
    badTag := "Project name not valid tag name"
    tooShort := "Project name too short"
    tooLong  := "Project name too long"

    verifyProjName("",        tooShort)
    verifyProjName("a",       tooShort)
    verifyProjName("ab",      tooShort)
    verifyProjName("abc",     null)
    verifyProjName("sys",     null)
    verifyProjName("abcd",    null)
    verifyProjName("fooBar4", null)
    verifyProjName("x"*62,    null)
    verifyProjName("x"*63,    tooLong)

    verifyProjName("abCd", null)
    verifyProjName("-acd", badTag)
    verifyProjName("acd-", badTag)
    verifyProjName("3bcd", badTag)
    verifyProjName("Abcd", badTag)
    verifyProjName("abcD", null)
    verifyProjName("a3b4", null)
    verifyProjName("ab d", badTag)
    verifyProjName("ab:d", badTag)
  }

  Void verifyProjName(Str n, Str? expect)
  {
    msg := HxUtil.checkProjNameErr(n)
    // echo("-- $n | $msg")
    verifyEq(msg, expect)
    if (expect == null) HxUtil.checkProjName(n)
    else verifyErr(ArgErr#) { HxUtil.checkProjName(n) }
  }

//////////////////////////////////////////////////////////////////////////
// Settings
//////////////////////////////////////////////////////////////////////////

  Void testSettings()
  {
    x := TestSettings(Etc.dict0)
    verifyEq(x.int, 99)
    verifyEq(x.num, n(99))
    verifyEq(x.dur, 99sec)
    verifyEq(x.bool, false)
    verifyEq(x.isEmpty, true)
    verifyEq(x.has("int"), false)
    verifyEq(x.missing("int"), true)
    verifyEq(x["int"], null)
    verifyErr(UnknownNameErr#) { x->int }

    x = TestSettings(Etc.dict4("int", n(3), "num", n(4, "kW"), "dur", n(5, "hr"), "bool", m))
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
    x = TestSettings(Etc.dict4("int", "bad", "num", "bad", "dur", n(5), "bool", true), onErr)
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
internal const class TestSettings : Settings
{
  static new wrap(Dict d, |Str|? onErr := null) { create(TestSettings#, d, onErr) }
  new make(Dict d, |This| f) : super(d) { f(this) }
  @Setting const Int int := 99
  @Setting const Number num := Number(99)
  @Setting const Duration dur := 99sec
  @Setting const Bool bool
}

