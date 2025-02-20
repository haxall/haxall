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

    // static Fantom methods
    verifyEval(Str<|Date.today|>, Date.today)
    verifyEval(Str<|sys::Date.today|>, Date.today)
    verifyEval(Str<|Date.fromStr("2024-04-21")|>, Date("2024-04-21"))
    verifyEval(Str<|sys::Date.fromStr("2024-04-21")|>, Date("2024-04-21"))

    // static Fantom fields
    verifyEval(Str<|FantomEx.sx|>, "static field")
    verifyEval(Str<|testAxon::FantomEx.sx|>, "static field")

    // instance Fantom method
    verifyEval(Str<|FantomEx.make.bar|>, "bar!")
    verifyEval(Str<|FantomEx.make.add1(4, 5)|>, n(9))

    // instance fields
    verifyEval(Str<|FantomEx.make.foo|>, "foo!")

    // coercion out of Fantom
    verifyEval(Str<|Float.posInf|>, Number.posInf)
    verifyEval(Str<|Int.fromStr("3")|>, n(3))
    verifyEval(Str<|Float.fromStr("3")|>, n(3))
    verifyEval(Str<|Duration.fromStr("3min")|>, n(3, "min"))

    // coercion into Fantom
    verifyEval(Str<|Int.fromStr("abc", 16)|>, n(0xabc))
    verifyEval(Str<|FantomEx.add2(3, 5)|>, n(8))
    verifyEval(Str<|FantomEx.add3(3sec, 5sec)|>, n(8, "sec"))
    verifyEval(Str<|FantomEx.filter(Point)|>, Filter("Point"))
    verifyEval(Str<|FantomEx.filter(foo==3)|>, Filter("foo==3"))
    verifyEval(Str<|FantomEx.filter(FooBar and mark and foo==3)|>, Filter("FooBar and mark and foo==3"))

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
  static Float add2(Int a, Float b) { b + a }
  static Duration add3(Duration a, Duration b) { b + a }
  static const Str sx := "static field"

  static Filter filter(Filter filter) { filter }
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

