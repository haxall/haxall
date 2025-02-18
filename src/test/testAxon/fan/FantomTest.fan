//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using haystack
using axon

**
** FantomTest
**
@Js
class FantomTest : HaystackTest
{
  Void test()
  {
    // global axon functions
    verifyEval(Str<|today()|>, Date.today)
    verifyEval(Str<|format(Date.today, "D-MMM-YY")|>, Date.today.toLocale("D-MMM-YY"))

    // static Fantom slots
    verifyEval(Str<|Date.today|>, Date.today)
    verifyEval(Str<|sys::Date.today|>, Date.today)
    verifyEval(Str<|Date.fromStr("2024-04-21")|>, Date("2024-04-21"))
    verifyEval(Str<|sys::Date.fromStr("2024-04-21")|>, Date("2024-04-21"))
    verifyEval(Str<|Float.posInf|>, Float.posInf)
    verifyEval(Str<|sys::Float.posInf|>, Float.posInf)

    // instance Fantom slots
    verifyEval(Str<|FantomEx.make.foo|>, "foo!")
    verifyEval(Str<|FantomEx.make.bar|>, "bar!")
    verifyEval(Str<|FantomEx.make.add1(4, 5)|>, n(9))

    // errors
    verifyErrMsg(UnknownTypeErr#, "Bad") { eval("Bad.foo") }
    verifyErrMsg(UnknownTypeErr#, "sys::Bad") { eval("sys::Bad.foo") }
    verifyErrMsg(UnknownTypeErr#, "util::Console") { eval("util::Console.cur") }
    verifyErrMsg(UnknownSlotErr#, "testAxon::FantomEx.bad") { eval("FantomEx.make.bad") }
  }

  Void verifyEval(Str expr, Obj? expect)
  {
    actual := eval(expr)
    //echo("-- $expr | $actual ?= $expect")
    verifyEq(actual, expect)
  }

  Obj? eval(Str expr)
  {
    FantomTestContext(this).eval(expr)
  }

}

**************************************************************************
** FantomEx
**************************************************************************

@Js
class FantomEx
{
  Str foo  := "foo!"
  Str bar() { "bar!" }
  Number add1(Number a, Number b) { a + b }
}

**************************************************************************
** FantomTestContext
**************************************************************************

@Js
internal class FantomTestContext : TestContext
{
  new make(HaystackTest test) : super(test)
  {
    pods := "sys,testAxon".split(',').map |p->Pod| { Pod.find(p) }
    this.ffi = FantomAxonFFI(pods)
  }

  override AxonFFI? ffi
}

