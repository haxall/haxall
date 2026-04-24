//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Apr 2026  Brian Frank  Creation
//

using util
using xeto
using xetom
using xetoc
using haystack

**
** RemoteReposTest
**
class RemoteReposTest : AbstractXetoTest
{
  Void test()
  {
    verifyLocal
    verifyRemote("xetodev", `https://xeto.dev`)
    verifyRemote("cc", `https://github.com/Project-Haystack/xeto-cc`)
  }

  Void verifyLocal()
  {
    r := XetoEnv.cur.repo
    verifyEq(r.isLocal, true)
    verifyEq(r.isRemote, false)
    verifyEq(r.name, "local")
    verifyEq(r.uri, `local:/`)
  }

  Void verifyRemote(Str n, Uri uri)
  {
    r := XetoEnv.cur.remoteRepos.get(n)
    verifyEq(r.isLocal, false)
    verifyEq(r.isRemote, true)
    verifyEq(r.name, n)
    verifyEq(r.uri, uri)
  }
}

