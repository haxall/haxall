//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Nov 2025  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** MixinTest
**
@Js
class MixinTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    ns        := createNamespace(["hx.test.xeto"])
    lib       := ns.lib("hx.test.xeto")
    str       := ns.spec("sys::Str")
    site      := ns.spec("ph::Site")
    testSite  := lib.spec("TestSite")
    sitem     := lib.spec("Site")
    sitex     := ns.specx(site)
    testSitex := ns.specx(testSite)

    verifyEq(sitem.isType, false)
    verifyEq(sitem.isMixin, true)
    verifyEq(sitem.flavor, SpecFlavor.mixIn)
    verifyEq(sitem.meta["mixin"], Marker.val)
    verifySame(sitem.base, site)
    verifySame(sitem.type, site)

    verifyEq(ns.mixinsFor(str), Spec[,])
    verifyEq(ns.mixinsFor(site), Spec[sitem])
    verifyEq(ns.mixinsFor(testSite), Spec[sitem])
    verifyEq(ns.mixinsFor(testSite).isImmutable, true)

    verifyEq(lib.mixins, Spec[sitem])
    verifySame(lib.mixinFor(site), sitem)
    verifyEq(lib.mixinFor(ns.spec("sys::Str"), false), null)
    verifyEq(lib.mixinFor(lib.spec("EquipA"), false), null)
    verifyErr(UnknownSpecErr#) { lib.mixinFor(ns.spec("sys::Str")) }
    verifyErr(UnknownSpecErr#) { lib.mixinFor(ns.spec("sys::Str"), true) }

    // specx meta

    verifySame(str, ns.specx(str))
    verifySpecx(site, sitex)
    verifySpecx(testSite, testSitex)
    verifySame(sitex.metaOwn, site.metaOwn)
    verifyNotSame(sitex.meta, site.meta)
    verifySame(sitex.meta, sitex.meta)
    verifyDictEq(sitex.meta, ["doc":site.metaOwn["doc"], "foo":"building"])
    verifyDictEq(testSitex.meta, ["doc":testSite.metaOwn["doc"], "foo":"building"])

    // specx meta merge of orig slots
    areaDoc := site.slot("area").meta["doc"]
    areaMeta := ["doc":areaDoc, "val":n(0), "quantity":UnitQuantity.area, "maybe":m, "foo":"AreaEditor", "bar":"hello"]
    area := sitex.slot("area")
    verifyDictEq(area.meta, areaMeta)
    verifyDictEq(testSitex.slot("area").meta, areaMeta)
    verifyNotSame(site.slotOwn("area"), area)
    verifySame(sitex.slotOwn("area"), area)
    verifySame(sitex.member("area"), area)
    verifySame(sitex.membersOwn.get("area"), area)
    verifySame(sitex.members.get("area"), area)

    // specx new slots
    newSlot := sitex.slot("newSlot")
    verifyEq(testSite.slot("newSlot", false), null)
    verifySame(sitem.slot("newSlot"), newSlot)
    verifySame(testSitex.slot("newSlot"), newSlot)
    verifyEq(newSlot.name, "newSlot")
    verifyEq(newSlot.qname, "hx.test.xeto::Site.newSlot")
    verifySame(newSlot.type, str)
    verifyDictEq(newSlot.metaOwn, ["foo":"hi"])
  }

  Void verifySpecx(Spec m, Spec x)
  {
    verifySame(m.lib,        x.lib)
    verifySame(m.parent,     x.parent)
    verifySame(m.id,         x.id)
    verifySame(m.name,       x.name)
    verifySame(m.qname,      x.qname)
    verifySame(m.type,       x.type)
    verifySame(m.base,       x.base)
    verifySame(m.metaOwn,    x.metaOwn)
    verifySame(m.flavor,     x.flavor)
    verifySame(m.globalsOwn, x.globalsOwn)
    verifySame(m.globals,    x.globals)
    verifySame(m.loc,        x.loc)
    verifySame(m.binding,    x.binding)
    verifySame(m.fantomType, x.fantomType)
    verifySame(m.of(false),  x.of(false))
    verifySame(m.ofs(false), x.ofs(false))

    verifyEq(m.isMaybe,     x.isMaybe)
    verifyEq(m.isEnum,      x.isEnum)
    verifyEq(m.isChoice,    x.isChoice)
    verifyEq(m.isFunc,      x.isFunc)
    verifyEq(m.isType,      x.isType)
    verifyEq(m.isMixin,     x.isMixin)
    verifyEq(m.isGlobal,    x.isGlobal)
    verifyEq(m.isMeta,      x.isMeta)
    verifyEq(m.isSlot,      x.isSlot)
    verifyEq(m.isNone,      x.isNone)
    verifyEq(m.isSelf,      x.isSelf)
    verifyEq(m.isScalar,    x.isScalar)
    verifyEq(m.isMarker,    x.isMarker)
    verifyEq(m.isRef,       x.isRef)
    verifyEq(m.isMultiRef,  x.isMultiRef)
    verifyEq(m.isDict,      x.isDict)
    verifyEq(m.isList,      x.isList)
    verifyEq(m.isQuery,     x.isQuery)
    verifyEq(m.isInterface, x.isInterface)
    verifyEq(m.isComp,      x.isComp)
    verifyEq(m.isAnd,       x.isAnd)
    verifyEq(m.isOr,        x.isOr)
    verifyEq(m.isCompound,  x.isCompound)
    verifyEq(m.inheritanceDigest, x.inheritanceDigest)
  }

//////////////////////////////////////////////////////////////////////////
// XMeta Enum
//////////////////////////////////////////////////////////////////////////

  Void testEnum()
  {
echo("####### TODO")
    /*
    ns := createNamespace(["ph", "hx.test.xeto"])
    verifyEq(ns.lib("hx.test.xeto").hasXMeta, true)

    spec := ns.spec("ph::CurStatus")
    verifyErr(UnsupportedErr#) { spec.enum.xmeta }
    verifyErr(UnsupportedErr#) { spec.enum.xmeta("ok") }

    e := ns.xmetaEnum("ph::CurStatus")

    doc := spec.meta["doc"]
    verifyDictEq(e.xmeta, Etc.dictToMap(spec.meta).set("qux", "_self_"))
    verifyDictEq(e.xmeta("ok"), Etc.dictToMap(e.spec("ok").meta).set("color", "green"))
    verifyDictEq(e.xmeta("down"), Etc.dictToMap(e.spec("down").meta).set("color", "yellow"))
    verifyDictEq(e.xmeta("disabled"), e.spec("disabled").meta)

    // test ph::EnumLine where names are different than keys
    e = ns.xmetaEnum("ph::Phase")
    verifyDictEq(e.xmeta("L1"), Etc.dictToMap(e.spec("L1").meta).set("foo", "Line 1"))
    */
  }
}

