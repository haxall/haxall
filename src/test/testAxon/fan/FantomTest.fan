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
    verifyEval(Str<|Date.today|>, Date.today)
    verifyEval(Str<|sys::Date.today|>, Date.today)
    verifyEval(Str<|Date.fromStr("2024-04-21")|>, Date("2024-04-21"))
    verifyEval(Str<|sys::Date.fromStr("2024-04-21")|>, Date("2024-04-21"))

    verifyErrMsg(UnknownTypeErr#, "Bad") { eval("Bad.foo") }
    verifyErrMsg(UnknownTypeErr#, "sys::Bad") { eval("sys::Bad.foo") }
    verifyErrMsg(UnknownTypeErr#, "util::Console") { eval("util::Console.cur") }
  }

  Void verifyEval(Str expr, Obj? expect)
  {
    actual := eval(expr)
    // echo("-- $expr | $actual ?= $expect")
    verifyEq(actual, expect)
  }

  Obj? eval(Str expr)
  {
    FantomTestContext(this).eval(expr)
  }

}

**************************************************************************
** FantomTestContext
**************************************************************************

@Js
internal class FantomTestContext : TestContext
{
  new make(HaystackTest test) : super(test)
  {
    pods := "sys".split(',').map |p->Pod| { Pod.find(p) }
    this.ffi = FantomAxonFFI(pods)
  }

  override AxonFFI? ffi
}

