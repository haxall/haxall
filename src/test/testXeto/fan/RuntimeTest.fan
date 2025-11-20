//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Nov 2025  Brian Frank  Creation
//

using xeto
using haystack
using axon
using folio
using hx

**
** Tests that use hx::Runtime
**
class RuntimeTest : AbstractAxonTest
{
  @HxTestProj
  Void testInheritanceDigest()
  {
    addLib("ph")

    verifyErr(UnsupportedErr#) { ns.spec("sys::abstract").inheritanceDigest }
    verifyErr(UnsupportedErr#) { ns.spec("ph::Site.area").inheritanceDigest }

    verifyDigestEq(ns.spec("ph::Equip").inheritanceDigest, ns.spec("ph::Equip").inheritanceDigest)
    verifyDigestNotEq(ns.spec("ph::Equip").inheritanceDigest, ns.spec("ph::Ahu").inheritanceDigest)
    verifyDigestNotEq(ns.spec("ph::Ahu").inheritanceDigest, ns.spec("ph::Vav").inheritanceDigest)

    // create a/b in companion
    x := proj.companion
    x.add(x.parse("Alpha: Dict"))
    x.add(x.parse("Bravo: Dict"))
    ad1 := ns.spec("proj::Alpha").inheritanceDigest
    bd1 := ns.spec("proj::Bravo").inheritanceDigest
    verifyDigestNotEq(ad1, bd1)

    // now change b inheritance
    x.update(x.parse("Bravo: Alpha"))
    ad2 := ns.spec("proj::Alpha").inheritanceDigest
    bd2 := ns.spec("proj::Bravo").inheritanceDigest
    verifyDigestEq(ad1, ad2)
    verifyDigestNotEq(bd1, bd2)

    // now change a inheritance which changes b too
    x.update(x.parse("Alpha: Entity"))
    ad3 := ns.spec("proj::Alpha").inheritanceDigest
    bd3 := ns.spec("proj::Bravo").inheritanceDigest
    verifyDigestNotEq(ad2, ad3)
    verifyDigestNotEq(bd1, bd3)
    verifyDigestNotEq(bd2, bd3)

    // now create compound type
    x.add(x.parse("Charlie: Equip & Alpha"))
    ad4 := ns.spec("proj::Alpha").inheritanceDigest
    bd4 := ns.spec("proj::Bravo").inheritanceDigest
    cd4 := ns.spec("proj::Charlie").inheritanceDigest
    verifyDigestEq(ad3, ad4)
    verifyDigestEq(bd3, bd4)

    // verify compound type change
    x.update(x.parse("Charlie: Ahu & Alpha"))
    ad5 := ns.spec("proj::Alpha").inheritanceDigest
    bd5 := ns.spec("proj::Bravo").inheritanceDigest
    cd5 := ns.spec("proj::Charlie").inheritanceDigest
    verifyDigestEq(ad4, ad5)
    verifyDigestEq(bd4, bd5)
    verifyDigestNotEq(cd4, cd5)
  }

  Void verifyDigestEq(Int a, Int b)
  {
    //echo("== 0x$a.toHex")
    //echo("   0x$b.toHex")
    verifyEq(a, b)
  }

  Void verifyDigestNotEq(Int a, Int b)
  {
    //echo("!= 0x$a.toHex")
    //echo("   0x$b.toHex")
    verifyNotEq(a, b)
  }
}

