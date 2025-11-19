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
    ns       := createNamespace(["hx.test.xeto"])
    lib      := ns.lib("hx.test.xeto")
    str     := ns.spec("sys::Str")
    site     := ns.spec("ph::Site")
    testSite := lib.spec("TestSite")
    sitex    := lib.spec("Site")

    verifyEq(sitex.isType, false)
    verifyEq(sitex.isMixin, true)
    verifyEq(sitex.flavor, SpecFlavor.mixIn)
    verifyEq(sitex.meta["mixin"], Marker.val)
    verifySame(sitex.base, site)
    verifySame(sitex.type, site)

    verifyEq(lib.mixins, Spec[sitex])
    verifySame(lib.mixinFor(site), sitex)
    verifyEq(lib.mixinFor(ns.spec("sys::Str"), false), null)
    verifyEq(lib.mixinFor(lib.spec("EquipA"), false), null)
    verifyErr(UnknownSpecErr#) { lib.mixinFor(ns.spec("sys::Str")) }
    verifyErr(UnknownSpecErr#) { lib.mixinFor(ns.spec("sys::Str"), true) }

    verifyDictEq(ns.meta(site), ["doc":site.metaOwn["doc"], "foo":"building"])
    verifyDictEq(ns.meta(testSite), ["doc":testSite.metaOwn["doc"], "foo":"building"])
    verifyDictEq(ns.meta(str), str.meta)
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
    spec = ns.spec("ph::area")
    doc = spec.meta["doc"]
    verifyXMeta(ns, spec,
      ["doc":doc, "val":n(0), "quantity":UnitQuantity.area],
      ["doc":doc, "val":n(0), "quantity":UnitQuantity.area, "foo":"AreaEditor", "bar":"hello"])

    // Vav (inherited from Equip)
    spec = ns.spec("ph::Vav")
    doc = spec.meta["doc"]
    verifyXMeta(ns, spec,
      ["doc":doc],
      ["doc":doc, "qux":"Device"])
  }

  Void verifyXMeta(Namespace ns, Spec spec, Str:Obj meta, Str:Obj xmeta)
  {
    actual := ns.xmeta(spec.qname)
    verifyDictEq(spec.meta, meta)
    verifyDictEq(actual, xmeta)
  }

//////////////////////////////////////////////////////////////////////////
// XMeta Enum
//////////////////////////////////////////////////////////////////////////

  Void testEnum()
  {
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
  }
}

