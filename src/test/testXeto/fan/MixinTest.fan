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
    number    := ns.spec("sys::Number")
    site      := ns.spec("ph::Site")
    testSite  := lib.spec("TestSite")
    sitex     := ns.specx(site)
    testSitex := ns.specx(testSite)
    sitem     := lib.spec("Site")
    csm       := lib.spec("CurStatus")
    phasem    := lib.spec("Phase")
    specm     := lib.spec("Spec")
    funcs     := lib.spec("Funcs")

    verifyEq(sitem.isType, false)
    verifyEq(sitem.isMixin, true)
    verifyEq(sitem.flavor, SpecFlavor.mixIn)
    verifyEq(sitem.meta["mixin"], Marker.val)
    verifySame(sitem.base, site)
    verifySame(sitem.type, site)
    verifyFlavor(ns, sitem, SpecFlavor.mixIn)

    verifyEq(ns.mixinsFor(str), Spec[,])
    verifyEq(ns.mixinsFor(site), Spec[sitem])
    verifyEq(ns.mixinsFor(testSite), Spec[sitem])
    verifyEq(ns.mixinsFor(testSite).isImmutable, true)

    verifyEq(lib.mixins.list, Spec[csm, funcs, phasem, sitem, specm])
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
    areaMeta := ["doc":areaDoc, "val":n(0), "quantity":UnitQuantity.area, "maybe":m, "foo":"AreaEditor", "bar":"hello",
      "pattern":"(-?(?:0|[1-9]\\d*)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?[a-zA-Z%_/\$\\P{ASCII}]*|\"(?:NaN|-?INF)\")"]
    area := sitex.slot("area")
    verifySame(area.type, number)
    verifyDictEq(area.meta, areaMeta)
    verifyDictEq(testSitex.slot("area").meta, areaMeta)
    verifyNotSame(site.slotOwn("area"), area)
    verifySame(sitex.slotOwn("area"), area)
    verifySame(sitex.member("area"), area)
    verifySame(sitex.membersOwn.get("area"), area)
    verifySame(sitex.members.get("area"), area)
    verifyEq(sitem.slot("area").qname, "hx.test.xeto::Site.area")
    verifySame(sitem.slot("area").type, number)

    // specx new slots
    newSlot := sitex.slot("newSlot")
    verifyEq(testSite.slot("newSlot", false), null)
    verifySame(sitem.slot("newSlot"), newSlot)
    verifySame(testSitex.slot("newSlot"), newSlot)
    verifySame(ns.specx(testSitex.slot("newSlot")), newSlot)
    verifyEq(newSlot.name, "newSlot")
    verifyEq(newSlot.qname, "hx.test.xeto::Site.newSlot")
    verifySame(newSlot.type, str)
    verifyDictEq(newSlot.metaOwn, ["foo":"hi"])

    // lookup specx of global/slot
    spec := ns.spec("ph::PhEntity.area")
    verifySame(ns.specx(spec),  spec)
    spec = ns.spec("ph::Site.area")
    verifyDictEq(ns.specx(spec).meta, areaMeta)
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
// Enum
//////////////////////////////////////////////////////////////////////////

  Void testEnum()
  {
    ns := createNamespace(["ph", "hx.test.xeto"])

    // verify Specx.enum uses extended slot meta
    spec := ns.spec("ph::CurStatus")
    specx := ns.specx(spec)
    verifyDictEq(specx.meta, Etc.dictToMap(spec.meta).set("qux", "_self_"))
    verifyEnumItem(spec, specx, "ok",     "green")
    verifyEnumItem(spec, specx, "down",    "yellow")
    verifyEnumItem(spec, specx, "disabled", null)

    // test Phase where names are different than keys
    spec = ns.spec("ph::Phase")
    specx = ns.specx(spec)
    verifyEnumItem(spec, specx, "L1", "Line 1")
    verifyEnumItem(spec, specx, "L1-L2", "Line 1 to Line 2")

    // Specx.enum raises exception for non-enum
    verifyErr(UnsupportedErr#) { ns.specx(ns.spec("ph::Site")).enum }
  }

  Void verifyEnumItem(Spec spec, Spec specx, Str key, Str? foo)
  {
    item  := spec.enum.spec(key)
    itemx := specx.enum.spec(key)
    if (foo == null)
    {
      verifySame(item, itemx)
      verifySame(spec.slot(item.name), specx.slot(item.name))
      return
    }
    verifyNotSame(item, itemx)
    verifyNotSame(spec.slot(item.name), specx.slot(item.name))
    verifySame(item, spec.slot(item.name))
    verifySame(itemx, specx.slot(item.name))
    verifyEq(item.meta["foo"], null)
    verifyEq(itemx.meta["foo"], foo)
    verifyDictEq(itemx.meta, Etc.dictSet(item.meta, "foo", foo))
  }
}

