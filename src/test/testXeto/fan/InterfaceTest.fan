//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Apr 2024  Brian Frank  Creation
//

using xeto
using haystack
using haystack::Dict  // TODO: need Dict.id
using haystack::Ref
using axon
using folio
using hx

**
** InterfaceTest
**
class InterfaceTest : AbstractXetoTest
{
  Void testNamespace()
  {
    verifyLocalAndRemote(["sys", "hx.test.xeto"]) |ns| { doTestNamespace(ns) }
  }

  private Void doTestNamespace(LibNamespace ns)
  {
if (ns.isRemote) return
    lib :=  ns.lib("hx.test.xeto")

    func := ns.spec("sys::Func")

    a := lib.type("InterfaceA")
    verifyEq(a.isType, true)
    verifyEq(a.isInterface, true)

    b := lib.type("InterfaceB")
    verifyEq(b.isType, true)
    verifyEq(b.isInterface, true)

    // ctors do *not* override from supertype
    am1 := a.slot("m1")
    bm1 := b.slot("m1")
    verifyEq(am1.base, func)
    verifyEq(bm1.base, func)

    // static do *not* override from supertype
    as1 := a.slot("s1")
    bs1 := b.slot("s1")
    verifyEq(as1.base, func)
    verifyEq(bs1.base, func)

    // instance slots *do* override from supertype
    ai1 := a.slot("i1")
    bi1 := b.slot("i1")
    verifyEq(ai1.base, func)
    verifySame(bi1.base, ai1)

    // verify b inherits s9 and i9, but not m9
    verifyEq(b.slot("m9", false), null)
    verifySame(b.slot("s9", false), a.slot("s9"))
    verifySame(b.slot("i9", false), a.slot("i9"))
  }
}

