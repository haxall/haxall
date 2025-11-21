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

    verifyEq(lib.mixins, Spec[sitem])
    verifySame(lib.mixinFor(site), sitem)
    verifyEq(lib.mixinFor(ns.spec("sys::Str"), false), null)
    verifyEq(lib.mixinFor(lib.spec("EquipA"), false), null)
    verifyErr(UnknownSpecErr#) { lib.mixinFor(ns.spec("sys::Str")) }
    verifyErr(UnknownSpecErr#) { lib.mixinFor(ns.spec("sys::Str"), true) }

    verifySpecx(site, sitex)
    verifySpecx(testSite, testSitex)
    verifySame(sitex.metaOwn, site.metaOwn)
    verifyNotSame(sitex.meta, site.meta)
    verifySame(sitex.meta, sitex.meta)
    verifyDictEq(sitex.meta, ["doc":site.metaOwn["doc"], "foo":"building"])
    verifyDictEq(testSitex.meta, ["doc":testSite.metaOwn["doc"], "foo":"building"])
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

    m.slots.each |s| { verifyEq(s.name, x.slot(s.name).name) }
  }

//////////////////////////////////////////////////////////////////////////
// XMeta
//////////////////////////////////////////////////////////////////////////

  Void testXMeta()
  {
    ns := createNamespace(["hx.test.xeto"])

    // Site (normal spec)
    spec := ns.spec("ph::Site")
    doc := spec.meta["doc"]
    verifyXMeta(ns, spec,
      ["doc":doc],
      ["doc":doc, "foo":"building"])

    // area (global spec)
    spec = ns.spec("ph::Site.area")
    doc = spec.meta["doc"]
    verifyXMeta(ns, spec,
      ["doc":doc, "val":n(0), "quantity":UnitQuantity.area, "maybe":m],
      ["doc":doc, "val":n(0), "quantity":UnitQuantity.area, "maybe":m, "foo":"AreaEditor", "bar":"hello"])

    // Vav (inherited from Equip)
    spec = ns.spec("ph::Vav")
    doc = spec.meta["doc"]
    verifyXMeta(ns, spec,
      ["doc":doc],
      ["doc":doc, "qux":"Device"])
  }

  Void verifyXMeta(Namespace ns, Spec spec, Str:Obj meta, Str:Obj xmeta)
  {
    actual := ns.specx(spec).meta
    verifyDictEq(spec.meta, meta)
    verifyDictEq(actual, xmeta)
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

