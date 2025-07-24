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

  @HxTestProj
  Void test()
  {
    addLib("hx.test")
    addLib("hx.test.xeto")
    addLib("hx.test.xeto.deep")

    // axon
    verifyResolve("today()", Date.today)

    // hx.test
    verifyResolve("testIncrement(3)", n(4))

    // hx.test.xeto
    verifyResolve("add2(2, 5)", n(7))

    // hx.test.xeto.deep
    verifyResolve("testDeepAdd(6, 3)", n(9))

    // sys
    verifyResolve("Str", proj.ns.spec("sys::Str"))
    verifyResolve("sys::Str", proj.ns.spec("sys::Str"))

    // ph
    verifyResolve("Site", proj.ns.spec("ph::Site"))
    verifyResolve("ph::Site", proj.ns.spec("ph::Site"))

    // ph.points
    verifyResolve("RunCmd", proj.ns.spec("ph.points::RunCmd"))
    verifyResolve("ph.points::RunCmd", proj.ns.spec("ph.points::RunCmd"))
  }

  Void verifyResolve(Str expr, Obj expect)
  {
    echo("--> $expr")
    actual := eval(expr)
    echo("  > $actual ?= $expect")
    verifyEq(actual, expect)
  }

}

