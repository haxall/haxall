//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Jul 2025  Brian Frank  Garden City Beach
//

using xeto
using xetom
using xetoc
using haystack
using axon
using folio
using hx

**
** EnvTest
**
class EnvTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Cache
//////////////////////////////////////////////////////////////////////////

  Void testCache()
  {
    env1 := ServerEnv.initPath
    a1 := env1.createNamespaceFromNames(["ph.points", "ph.attrs"])
    b1 := env1.createNamespaceFromNames(["ph.points", "ph.equips"])
    c1 := env1.createNamespaceFromNames(["ph.points", "ph.attrs", "ph.equips"])
    verifyLibsSame(env1, a1, b1)
    verifyLibsSame(env1, a1, c1)
    verifyLibsSame(env1, b1, c1)

    env2 := ServerEnv.initPath
    a2 := env2.createNamespaceFromNames(["ph.points", "ph.attrs"])
    b2 := env2.createNamespaceFromNames(["ph.points", "ph.equips"])
    c2 := env2.createNamespaceFromNames(["ph.points", "ph.attrs", "ph.equips"])
    verifyLibsSame(env2, a2, b2)
    verifyLibsSame(env2, a2, c2)
    verifyLibsSame(env2, b2, c2)

    verifyLibsNotSame(a1, a2)
    verifyLibsNotSame(b1, b2)
    verifyLibsNotSame(c1, c2)
  }

  Void verifyLibsSame(XetoEnv env, LibNamespace a, LibNamespace b)
  {
    verifySame(a.env, env)
    verifySame(b.env, env)
    a.libs.each |alib|
    {
      blib := b.lib(alib.name, false)
      if (blib == null) return
      verifySame(alib, blib)
    }
  }

  Void verifyLibsNotSame(LibNamespace a, LibNamespace b)
  {
    verifyNotSame(a.env, b.env)
    a.libs.each |alib|
    {
      blib := b.lib(alib.name, false)
      if (blib == null) return
      verifyNotSame(alib, blib)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Serialization
//////////////////////////////////////////////////////////////////////////

  Void testSerialization()
  {
    senv := ServerEnv.initPath
    benv := BrowserEnv()

    // serialize all libs
    sns := senv.createNamespaceFromNames(["ph", "ph.points"])
    buf := Buf()
    senv.saveLibs(buf.out, sns.libs)
echo("~~~ wrote $buf.size")

    // now load into browser env
    benv.loadLibs(buf.flip.in)
    bns := benv.createNamespaceFromNames(["ph", "ph.points"])
    verifySerialization(sns, bns)
  }

  Void verifySerialization(LibNamespace s, LibNamespace b)
  {
echo("--- server")
s.dump
echo("--- browser")
b.dump
    verifyEq(s.libs.join(","), b.libs.join(","))
  }
}

