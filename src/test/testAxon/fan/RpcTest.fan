//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Feb 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetom
using haystack
using axon

**
** RpcTest
**
@Js
class RpcTest : AxonTest
{
  CompSpace? cs

  override Void setup()
  {
    super.setup

    ns := XetoEnv.cur.resolveNamespace(["hx.test.xeto"])
    ns.lib("hx.test.xeto")
    cs = CompSpace(ns).install
  }

  override Void teardown()
  {
    CompSpace.uninstall
    super.teardown
  }

  Void test()
  {
    // literals
    verifyRpc("123", n(123))
    verifyRpc("\"hi\"", "hi")
    verifyRpc("null", null)

    // simple calls/exprs
    verifyRpc("today()", Date.today)
    verifyRpc("3 + 4", n(7))
    verifyRpc("(3 + 4) * 2", n(14))

    // variables, simple binary op
    verifyRpc("a + b", n(7)) |cx|
    {
      cx.eval("a: 3")
      cx.eval("b: 4")
    }

    // variables, more complicated ops
    verifyRpc("-c * (a + b)", n(21)) |cx|
    {
      cx.eval("a: 3")
      cx.eval("b: 4")
      cx.eval("c: 3 - 6")
    }

    // list with nulls
    verifyRpc("[a, b, c]", Obj?[n(1), null, n(3)]) |cx|
    {
      cx.eval("a: 1")
      cx.eval("b: null")
      cx.eval("c: 3")
    }

    // list + map
    verifyRpc("[a, b, c].map(v => 100 + v)", Obj?[n(101), n(102), n(103)]) |cx|
    {
      cx.eval("a: 1")
      cx.eval("b: 2")
      cx.eval("c: 3")
    }

    // call
    verifyRpc(Str<|a.upper + "," + b.upper|>, "ALPHA,BETA") |cx|
    {
      cx.eval("a: \"alpha\"")
      cx.eval("b: \"beta\"")
    }

    // handle this for components
    verifyRpc(Str<|[this.a, this.b, this.c, this.d]|>, ["alpha", null, n(123), "tue"]) |cx|
    {
      comp := CompObj()
      comp.set("a", "alpha")
      comp.set("c", n(123))
      comp.set("d", Weekday.tue) // map to haystack fidelity
      cx.defOrAssign("this", comp, FileLoc.unknown)
    }

  }

  Void verifyRpc(Str expr, Obj? expect, |AxonContext|? f := null)
  {
    c := makeContext
    s := makeContext

    if (f != null) f(c)
    d := AxonRpc.marshal(c, c.parse(expr))

    actual := AxonRpc.eval(s, d)

   /*
    echo
    echo("@@@@ $expr")
    echo("  expect: $expect")
    echo("  actual: $actual")
    */

    verifyValEq(actual, expect)
  }

  /*
  Void verifyRpcErr(Str expr)
  {
    c := makeContext
    e := c.parse(expr)
    verifyErr(ArgErr#) { AxonRpc.marshal(c, e) }
  }
  */

}

