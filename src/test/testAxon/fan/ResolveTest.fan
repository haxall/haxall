//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jul 2025  Brian Frank  Garden City Beach
//

using xeto
using haystack
using axon
using hx

**
** Test different scenarios for context resolveTop using
** unqualified and qualified names
**
class ResolveTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Eval with unqualified/qualified type/func names
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testEvals()
  {
    addLib("hx.test")
    addLib("hx.test.xeto")
    addLib("hx.test.xeto.deep")

    // axon
    verifyResolve("today()", Date.today)
    verifyResolve("axon::today()", Date.today)

    // hx.test
    verifyResolve("testIncrement(3)", n(4))
    verifyResolve("hx.test::testIncrement(3)", n(4))

    // hx.test.xeto
    verifyResolve("add2(2, 5)", n(7))
    verifyResolve("hx.test.xeto::add2(2, 5)", n(7))

    // hx.test.xeto.deep
    verifyResolve("testDeepAdd(6, 3)", n(9))
    verifyResolve("hx.test.xeto.deep::testDeepAdd(6, 3)", n(9))

    // sys
    verifyResolve("Str", proj.ns.spec("sys::Str"))
    verifyResolve("sys::Str", proj.ns.spec("sys::Str"))

    // ph
    verifyResolve("Site", proj.ns.spec("ph::Site"))
    verifyResolve("ph::Site", proj.ns.spec("ph::Site"))

    // ph.points
    verifyResolve("RunCmd", proj.ns.spec("ph.points::RunCmd"))
    verifyResolve("ph.points::RunCmd", proj.ns.spec("ph.points::RunCmd"))

    // parsing error one level
    verifyErr(SyntaxErr#) { eval("axon()::now()") }
    verifyErr(SyntaxErr#) { eval("axon(123)::now()") }

    // parsing error two levels
    verifyErr(SyntaxErr#) { eval("hx().test::testIncrement(3)") }
    verifyErr(SyntaxErr#) { eval("hx(3).test::testIncrement(3)") }
    verifyErr(SyntaxErr#) { eval("hx.test()::testIncrement(3)") }
    verifyErr(SyntaxErr#) { eval("hx.test(3)::testIncrement(3)") }

    // parsing error two+ level
    verifyErr(SyntaxErr#) { eval("hx().test.xeto.deep::testDeepAdd(6, 3)") }
    verifyErr(SyntaxErr#) { eval("hx(2).test.xeto.deep::testDeepAdd(6, 3)") }
    verifyErr(SyntaxErr#) { eval("hx(2, 3).test.xeto.deep::testDeepAdd(6, 3)") }
    verifyErr(SyntaxErr#) { eval("hx.test().xeto.deep::testDeepAdd(6, 3)") }
    verifyErr(SyntaxErr#) { eval("hx.test(2).xeto.deep::testDeepAdd(6, 3)") }
    verifyErr(SyntaxErr#) { eval("hx.test(2, 3).xeto.deep::testDeepAdd(6, 3)") }
    verifyErr(SyntaxErr#) { eval("hx.test.xeto().deep::testDeepAdd(6, 3)") }
    verifyErr(SyntaxErr#) { eval("hx.test.xeto(3).deep::testDeepAdd(6, 3)") }
    verifyErr(SyntaxErr#) { eval("hx.test.xeto.deep()::testDeepAdd(6, 3)") }
    verifyErr(SyntaxErr#) { eval("hx.test.xeto.deep(3)::testDeepAdd(6, 3)") }
  }

  Void verifyResolve(Str expr, Obj expect)
  {
    actual := eval(expr)
    verifyEq(actual, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Context resolveTop, resolveTopFn
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testContext()
  {
    addLib("ph")
    addLib("hx.test")

    cx := makeContext
    ns := cx.ns
    loc := Loc.synthetic

    now := ns.spec("axon::now").func.thunk
    verifyContext(cx.resolveTop(TopName(loc, null, "now")), now)
    verifyContext(cx.resolveTop(TopName(loc, "axon", "now")), now)
    verifyContext(cx.resolveTopFn("now"), now)
    verifyContext(cx.resolveTopFn("axon::now"), now)

    incr := ns.spec("hx.test::testIncrement").func.thunk
    verifyContext(cx.resolveTop(TopName(loc, null, "testIncrement")), incr)
    verifyContext(cx.resolveTop(TopName(loc, "hx.test", "testIncrement")), incr)
    verifyContext(cx.resolveTopFn("testIncrement"), incr)
    verifyContext(cx.resolveTopFn("hx.test::testIncrement"), incr)

    site := ns.spec("ph::Site")
    verifyContext(cx.resolveTop(TopName(loc, null, "Site")), site)
    verifyContext(cx.resolveTop(TopName(loc, "ph", "Site")), site)

    verifyBadResolveTop(TopName(loc, "badLib", "badName"), UnknownLibErr#)
    verifyBadResolveTop(TopName(loc, "axon", "badName"),   UnknownSpecErr#)
    verifyBadResolveTop(TopName(loc, "sys", "BadName"),    UnknownSpecErr#)

    verifyBadResolveTopFn("bad",             EvalErr#)
    verifyBadResolveTopFn("badLib::badName", UnknownLibErr#)
    verifyBadResolveTopFn("axon::badName",   UnknownSpecErr#)
    verifyBadResolveTopFn("Site",            UnknownFuncErr#)
    verifyBadResolveTopFn("ph::Site",        UnknownFuncErr#)
  }

  Void verifyContext(Obj a, Obj b)
  {
    verifySame(a, b)
  }

  Void verifyBadResolveTop(TopName name, Type errType)
  {
    cx := makeContext
    verifyEq(cx.resolveTop(name, false), null)
    verifyErr(errType) { cx.resolveTop(name) }
    verifyErr(errType) { cx.resolveTop(name, true) }
  }

  Void verifyBadResolveTopFn(Str name, Type errType)
  {
    cx := makeContext
    verifyEq(cx.resolveTopFn(name, false), null)
    verifyErr(errType) { cx.resolveTopFn(name) }
    verifyErr(errType) { cx.resolveTopFn(name, true) }
  }

}

