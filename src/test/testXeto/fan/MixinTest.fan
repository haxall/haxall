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

  Void testReflect()
  {
    ns := createNamespace(["hx.test.xeto"])
    lib := ns.lib("hx.test.xeto")
    t := ns.spec("ph::Site")
    m := lib.spec("Site")

    verifyEq(m.isType, false)
    verifyEq(m.isMixin, true)
    verifyEq(m.flavor, SpecFlavor.mixIn)
    verifyEq(m.meta["mixin"], Marker.val)
    verifySame(m.base, t)
    verifySame(m.type, t)
  }
}

