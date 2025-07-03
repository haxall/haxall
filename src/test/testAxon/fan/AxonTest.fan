//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2019  Brian Frank  Creation
//

using xeto
using haystack
using axon

**
** AxonTest
**
@Js
abstract class AxonTest : HaystackTest
{

  AxonContext makeContext()
  {
    cx := TestContext(this)
    return cx
  }

  Obj? eval(Str s) { makeContext.eval(s) }

  Void verifyEval(Str src, Obj? expected)
  {
    debug := false
    if (debug)
    {
      echo
      echo("================")
      src.splitLines.each |str, i| { echo(line(i, str)) }
    }

    // verify we can parse, encode, and reparse
    cx := makeContext
    expr := cx.parse(src)
    src = expr.toStr

    if (debug)
    {
      echo("----------------")
      src.splitLines.each |str, i| { echo(line(i, str)) }
    }

    actual := cx.eval(src)
    if (actual is Dict) actual = Etc.dictToMap(actual)
    //echo(":: $src | $actual ?= $expected")

    verifyEq(actual, expected)
  }

  Void verifyEvalErr(Str axon, Type? errType)
  {
    expr := Parser(Loc.eval, axon.in).parse
    cx := makeContext
    EvalErr? err := null
    try { expr.eval(cx) } catch (EvalErr e) { err = e }
    if (err == null) fail("EvalErr not thrown: $axon")
    if (errType == null)
    {
      verifyNull(err.cause)
    }
    else
    {
      if (err.cause == null) fail("EvalErr.cause is null: $axon")
      verifyErr(errType) { throw err.cause }
    }
  }

  Str line(Int i, Str s)
  {
    i.plus(1).toStr.padl(2) + ": " + s
  }
}

**************************************************************************
** TestContext
**************************************************************************

@Js
internal class TestContext : AxonContext
{
  new make(HaystackTest test) { this.test = test }

  HaystackTest test

  static const Str:Fn core := FantomFn.reflectType(CoreLib#)

  override Dict? deref(Ref id) { null }

  override FilterInference inference() { FilterInference.nil }

  override Dict toDict() { Etc.emptyDict }

  override DefNamespace ns() { test.ns }

  override Fn? findTop(Str name, Bool checked := true)
  {
    if (name.contains("::")) name = name[name.indexr(":")+1..-1]
    return core.getChecked(name, checked)
  }
}

