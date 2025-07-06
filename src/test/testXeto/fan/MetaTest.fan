//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Dec 2024  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** MetaTest
**
@Js
class MetaTest : AbstractXetoTest
{

  Void testHxTestLib()
  {
    verifyLocalAndRemote(["sys", "hx.test.xeto", "hx.test.xeto.deep"]) |ns| { doTestHxTestLib(ns) }
  }

  private Void doTestHxTestLib(LibNamespace ns)
  {
    ns.libs
    lib := ns.lib("hx.test.xeto")

    q := lib.metaSpec("metaQ")
    r := lib.metaSpec("metaR")  // noInherit
    n := lib.metaSpec("metaNum")
    a := lib.type("MetaInheritA")
    b := lib.type("MetaInheritB")
    s := lib.type("MetaInheritB")
    ax := a.slot("x")
    ay := a.slot("y")
    bx := b.slot("x")
    by := b.slot("y")

    verifyHasMeta(a,  a.meta,  ["metaQ":m, "metaR":m])
    verifyHasMeta(ax, ax.meta, ["metaQ":m, "metaR":m])
    verifyHasMeta(ay, ay.meta, ["metaQ":m, "metaR":m])

    verifyHasMeta(b,  b.meta,  ["metaNum":Number(123), "metaQ":m])
    verifyHasMeta(bx, bx.meta, ["metaQ":m, "metaR":m])
    verifyHasMeta(by, by.meta, ["metaQ":m])

    // verify xmeta is inferred from meta defs
    alpha := ns.spec("hx.test.xeto::Alpha")
    xmeta := ns.xmeta(alpha.qname)
    verifyHasMeta(alpha, xmeta, ["metaQ":m, "metaNum":Number(456)])

    // verify normal instance doesn't infer from metaNum
    inst := ns.instance("hx.test.xeto.deep::norm-instance")
    verifyDictEq(inst, ["id":inst.id, "metaNum":"987"])
  }

  Void verifyHasMeta(Spec x, Dict actual, Str:Obj expect)
  {
    actual = Etc.dictRemoveAll(actual, ["doc", "val"])
    // echo("\n>> $x.qname $actual ?= $expect")
    verifyDictEq(actual, expect)
  }

}

