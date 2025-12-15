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

  private Void doTestHxTestLib(Namespace ns)
  {
    ns.libs
    lib := ns.lib("hx.test.xeto")

    mix := lib.mixinFor(ns.spec("sys::Spec"))

    q  := mix.slot("metaQ")
    r  := mix.slot("metaR")  // noInherit
    n  := mix.slot("metaNum")
    verifySame(ns.metas.get(q.name), q)
    verifySame(ns.metas.get(r.name), r)
    verifySame(ns.metas.get(n.name), n)

    a  := lib.type("MetaInheritA")
    b  := lib.type("MetaInheritB")
    a2 := lib.type("MetaInheritAltA")
    b2 := lib.type("MetaInheritAltB")
    ax := a.slot("x")
    ay := a.slot("y")
    az := a.slot("z")
    bx := b.slot("x")
    by := b.slot("y")
    bz := b.slot("z")

    verifyHasMeta(a,  a.meta,  ["metaQ":m, "metaR":m])
    verifyHasMeta(ax, ax.meta, ["metaQ":m, "metaR":m, "transient":m])
    verifyHasMeta(ay, ay.meta, ["metaQ":m, "metaR":m, "transient":m])
    verifyHasMeta(az, az.meta, [:])

    verifyHasMeta(b,  b.meta,  ["metaNum":Number(123), "metaQ":m])
    verifyHasMeta(bx, bx.meta, ["metaQ":m, "metaR":m, "transient":m])
    verifyHasMeta(by, by.meta, ["metaQ":m, "transient":m])
    verifyHasMeta(bz, bz.meta, [:])

    // alts use embedded meta
    verifyHasMeta(a2, a.meta,  ["metaQ":m, "metaR":m])
    verifyHasMeta(b2, b.meta,  ["metaNum":Number(123), "metaQ":m])

    // verify xmeta is inferred from meta defs
    /* TODO
    alpha := ns.spec("hx.test.xeto::Alpha")
    xmeta := ns.xmeta(alpha.qname)
    verifyHasMeta(alpha, xmeta, ["metaQ":m, "metaNum":Number(456)])
    */

    // verify normal instance doesn't infer from metaNum
    inst := ns.instance("hx.test.xeto.deep::norm-instance")
    verifyDictEq(inst, ["id":inst.id, "metaNum":"987"])

    verifyEq(bx.isTransient, true)
    verifyEq(by.isTransient, true)
    verifyEq(bz.isTransient, false)
  }

  Void verifyHasMeta(Spec x, Dict actual, Str:Obj expect)
  {
    actual = Etc.dictRemoveAll(actual, ["doc", "val"])
    // echo("\n>> $x.qname $actual ?= $expect")
    // Etc.dictDump(actual)
    verifyDictEq(actual, expect)
    verifyEq(x.isTransient, expect["transient"] != null)
  }

}

