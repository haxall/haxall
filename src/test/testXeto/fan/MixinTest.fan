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

}

