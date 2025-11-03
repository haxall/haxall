//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//  10 Oct 2025  Matthew Giannini Creation
//

using concurrent
using xeto
using xetom
using haystack

**
** CompSpaceTest
**
class CompSpaceTest: AbstractXetoTest
{
  Void testUnmountRemovesTargetLinks()
  {
    ns := createNamespace(CompTest.loadTestLibs)
    cs := CompSpace(ns).load(CompTest.loadTestXeto)

    TestAdd c := cs.readById(Ref("c"))
    c.set("in2", TestVal(100))
    verifyEq(c.get("in2"), TestVal.makeNum(100))
    verifyEq(c.links.listOn("in2").size, 1)
    cs.root.remove("b")
    // echo(cs.save)
    verifyEq(c.links.listOn("in2").size, 0)
    verifyEq(c.get("in2"), TestVal.makeNum(0))
  }
}
