//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Feb 2025  Brian Frank  Creation
//

using util
using xeto
using xeto::Dict
using haystack

**
** FuncTest
**
@Js
class FuncTest : AbstractXetoTest
{
  Void testNamespace()
  {
    verifyLocalAndRemote(["sys", "hx.test.xeto"]) |ns| { doTestNamespace(ns) }
  }

  private Void doTestNamespace(LibNamespace ns)
  {
    lib := ns.lib("hx.test.xeto")

    num := ns.spec("sys::Number")
    verifyEq(num.isGlobal, false)
    verifyEq(num.isType, true)
    verifyEq(num.isFunc, false)
    verifyErr(UnsupportedErr#) { num.func }

    f := lib.spec("add")
    verifyEq(f.isGlobal, true)
    verifyEq(f.isFunc, true)
    verifyEq(f.func.arity, 2)
    verifyEq(f.func.params.size, 2)
    verifyEq(f.func.params[0].name, "a"); verifySame(f.func.params[0].type, num)
    verifyEq(f.func.params[1].name, "b"); verifySame(f.func.params[1].type, num)
    verifySame(f.func.returns.type, num)
  }
}

