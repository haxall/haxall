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
    verifyLocalAndRemote(["sys", "hx.test.xeto"]) |ns| { doTestHxTestLib(ns) }
  }

  private Void doTestHxTestLib(LibNamespace ns)
  {
    lib := ns.lib("hx.test.xeto")
    q := lib.metaSpec("metaQ")
    r := lib.metaSpec("metaR")
    a := lib.type("MetaInheritA")
    b := lib.type("MetaInheritB")
    ax := a.slot("x")
    ay := a.slot("y")
    bx := b.slot("x")
    by := b.slot("y")

    verifyHasMeta(a,  [q, r])
    verifyHasMeta(ax, [q, r])
    verifyHasMeta(ay, [q, r])

    verifyHasMeta(b,  [q])
    verifyHasMeta(bx, [q, r])
    verifyHasMeta(by, [q])
  }

  Void verifyHasMeta(Spec x, Spec[] expect)
  {
    keys := Etc.dictNames(x.meta)
    keys.remove("doc")
    keys.remove("val")
    // echo("\n>> $x.qname $keys ?= $expect")
    verifyEq(keys.sort.join(","), expect.join(",") { it.name })
  }

}

