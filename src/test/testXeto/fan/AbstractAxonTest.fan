//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Apr 2024  Brian Frank  Creation
//

using xeto
using xetom
using haystack
using axon
using folio
using hx

**
** AbstractAxonTest
**
abstract class AbstractAxonTest : HxTest
{
  LibNamespace initNamespace(Str[] libs)
  {
    // nuke existing using recs
    rt.libs.clear

    // add new using recs
    rt.libs.addAll(libs)

    // sync
    rt.sync
    ns := rt.ns
// TODO
//    verifySame(ns.sysLib, LibNamespace.system.sysLib)
    return ns
  }

  LibNamespace xns()
  {
    rt.ns
  }

  Void verifyEval(Str expr, Obj? expect)
  {
    verifyEq(makeContext.eval(expr), expect)
  }

  Void verifySpec(Str expr, Str qname)
  {
    cx := makeContext
    x := cx.eval(expr)
    // echo("::: $expr => $x [$x.typeof]")
    verifySame(x, xns.type(qname))
  }

  Void verifyEvalErr(Str expr, Type? errType)
  {
    EvalErr? err := null
    try { eval(expr) } catch (EvalErr e) { err = e }
    if (err == null) fail("EvalErr not thrown: $expr")
    if (errType == null)
    {
      verifyNull(err.cause)
    }
    else
    {
      if (err.cause == null) fail("EvalErr.cause is null: $expr")
      verifyErr(errType) { throw err.cause }
    }
  }

  Obj? toHay(Obj? x)
  {
    XetoUtil.toHaystack(x)
  }

}

