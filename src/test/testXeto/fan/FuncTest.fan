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
    lib :=  ns.lib("hx.test.xeto")

    f := lib.spec("add")
    verifyEq(f.isGlobal, true)
    verifyEq(f.isFunc, true)

    c:= lib.type("MyClass")
    verifyEq(c.isType, true)
    verifyEq(c.isInterface, true)
  }
}

