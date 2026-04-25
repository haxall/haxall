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
  XetoEnv? env
  RemoteRepoRegistry? reg

  This initEnv()
  {
    tempDir := this.tempDir.normalize
    path := Env.cur.path.dup.insert(0, tempDir)
    this.env = ServerEnv("test", path)
    this.reg = env.remoteRepos
    verifyEq(env.workDir, tempDir)
    verifyEq(env.installDir, tempDir)
    return this
  }

  Void test()
  {
    initEnv
    config := env.workDir.plus(`etc/xeto/config.props`)
    verifyEq(config.exists, false)

    // verify installed setup
    verifyLocal
    verifyRemote("xetodev", `https://xeto.dev`, Etc.dict0)
    verifyRemote( "cc", `https://github.com/Project-Haystack/xeto-cc`, Etc.dict0)

    // not found remote repos
    verifyEq(reg.get("badone", false), null)
    verifyEq(reg.getByUri(`badone`, false), null)
    verifyErr(UnresolvedErr#) { reg.get("badone") }
    verifyErr(UnresolvedErr#) { reg.get("badone", true) }
    verifyErr(UnresolvedErr#) { reg.getByUri(`badone`) }
    verifyErr(UnresolvedErr#) { reg.getByUri(`badone`, true) }

    // add new one
    n1 := "test1"
    u1  := `http:/test-1/`
    m1 := Etc.dict3("m", m, "date", Date.today, "who", "me!")
    r1 := reg.add(n1, u1, m1)
    r := verifyRemote(n1, u1, m1)
    verifySame(r, r1)

    // verify saved config, reload and verify again
    verifyEq(config.exists, true)
    initEnv
    r1 = verifyRemote(n1, u1, m1)

    // now add another one
    n2 := "test2"
    u2  := `http:/test-2/`
    m2 := Etc.dict1("ts", DateTime.now)
    r2 := reg.add(n2, u2, m2)
    r = verifyRemote(n2, u2, m2)
    verifySame(r, r2)

    // verify saved config, reload and verify again
    verifyEq(config.exists, true)
    initEnv
    r1 = verifyRemote(n1, u1, m1)
    r2 = verifyRemote(n2, u2, m2)

    // now remove test1
    reg.remove(n1)
    verifyEq(reg.get(n1, false), null)
    verifyRemote(n2, u2, m2)

    // verify saved config, reload and verify again
    verifyEq(config.exists, true)
    initEnv
    verifyEq(reg.get(n1, false), null)
    verifyRemote(n2, u2, m2)

    // remove test2
    reg.remove(n2)
    verifyEq(reg.get(n1, false), null)
    verifyEq(reg.get(n2, false), null)

    // verify saved config, reload and verify again
    verifyEq(config.exists, true)
    initEnv
    verifyEq(reg.get(n1, false), null)
    verifyEq(reg.get(n2, false), null)

    // verify removing bad repo
    verifyErr(UnresolvedErr#) { reg.remove("badone") }

    // verify cannot remove from futher up path
    verifyErr(Err#) { reg.remove("xetodev") }
    verifyRemote("xetodev", `https://xeto.dev`, Etc.dict0)
  }

  Void verifyLocal()
  {
    r := env.repo
    verifyEq(r.isLocal, true)
    verifyEq(r.isRemote, false)
    verifyEq(r.name, "local")
    verifyEq(r.uri, `local:/`)
  }

  RemoteRepo verifyRemote(Str n, Uri uri, Dict meta)
  {
    reg := env.remoteRepos
    r := reg.get(n)

    verifyEq(r.isLocal, false)
    verifyEq(r.isRemote, true)
    verifyEq(r.name, n)
    verifyEq(r.uri, uri)
    verifyDictEq(r.meta, meta)

    verifyEq(reg.list.containsSame(r), true)
    verifySame(reg.get(n), r)
    verifySame(reg.getByUri(uri), r)

    return r
  }
}

