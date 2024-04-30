//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Apr 2024  Brian Frank  Creation
//

using xeto
using haystack
using haystack::Dict
using haystack::Ref
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
    rt.db.readAll(Filter("using")).each |r| { rt.db.commit(Diff(r, null, Diff.remove)) }

    // add new using recs
    libs.each |lib| { addRec(["using":lib]) }

    // sync
    rt.sync
    ns := rt.ns.xeto
    verifySame(ns.sysLib, LibRepo.cur.systemNamespace.sysLib)
    return ns
  }

  LibNamespace xns()
  {
    rt.ns.xeto
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

}

