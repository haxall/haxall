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

    verifyErr(UnsupportedErr#) { ns.spec("sys::Spec.abstract").inheritanceDigest }
    verifyErr(UnsupportedErr#) { ns.spec("ph::Site.area").inheritanceDigest }

    verifyDigestEq(ns.spec("ph::Equip").inheritanceDigest, ns.spec("ph::Equip").inheritanceDigest)
    verifyDigestNotEq(ns.spec("ph::Equip").inheritanceDigest, ns.spec("ph::Ahu").inheritanceDigest)
    verifyDigestNotEq(ns.spec("ph::Ahu").inheritanceDigest, ns.spec("ph::Vav").inheritanceDigest)

    // create a/b in companion
    x := proj.companion
    aId := x.add(x.parse("Alpha: Dict")).id
    bId := x.add(x.parse("Bravo: Dict")).id
    ad1 := ns.spec("proj::Alpha").inheritanceDigest
    bd1 := ns.spec("proj::Bravo").inheritanceDigest
    verifyDigestNotEq(ad1, bd1)

    // now change b inheritance
    x.update(Etc.dictSet(x.parse("Bravo: Alpha"), "id", bId))
    ad2 := ns.spec("proj::Alpha").inheritanceDigest
    bd2 := ns.spec("proj::Bravo").inheritanceDigest
    verifyDigestEq(ad1, ad2)
    verifyDigestNotEq(bd1, bd2)

    // now change a inheritance which changes b too
    x.update(Etc.dictSet(x.parse("Alpha: Entity"), "id", aId))
    ad3 := ns.spec("proj::Alpha").inheritanceDigest
    bd3 := ns.spec("proj::Bravo").inheritanceDigest
    verifyDigestNotEq(ad2, ad3)
    verifyDigestNotEq(bd1, bd3)
    verifyDigestNotEq(bd2, bd3)

    // now create compound type (verify unresolved names become proj::Foo
    ast := x.parse("Charlie: Equip & Alpha { list: List<of:Alpha> }")
    verifyEq(ast["base"], Ref("sys::And"))
    verifyEq(ast["ofs"], Obj?[Ref("ph::Equip"), Ref("proj::Alpha")])
    slot := (ast["slots"] as Grid).find { it->name == "list" }
    verifyDictEq(slot, ["name":"list", "type":Ref("sys::List"), "of":Ref("proj::Alpha")])
    cId := x.add(ast).id
    ad4 := ns.spec("proj::Alpha").inheritanceDigest
    bd4 := ns.spec("proj::Bravo").inheritanceDigest
    cd4 := ns.spec("proj::Charlie").inheritanceDigest
    verifyDigestEq(ad3, ad4)
    verifyDigestEq(bd3, bd4)

    // verify compound type change
    x.update(Etc.dictSet(x.parse("Charlie: Ahu & Alpha"), "id", cId))
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

