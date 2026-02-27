//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Feb 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon

**
** RpcTest
**
@Js
class RpcTest : AxonTest
{
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

    // list
    verifyRpc("[a, b, c]", Obj?[n(1), n(2), n(3)]) |cx|
    {
      cx.eval("a: 1")
      cx.eval("b: 2")
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
    Etc.dictDump(d)
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

