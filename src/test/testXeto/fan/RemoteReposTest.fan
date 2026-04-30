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

//////////////////////////////////////////////////////////////////////////
// Config
//////////////////////////////////////////////////////////////////////////

  Void testConfig()
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
    u1  := `http://test-1/`
    m1 := Etc.dict3("m", m, "date", Date.today, "who", "me!")
    r1 := reg.add(n1, u1, m1)
    r := verifyRemote(n1, u1, m1)
    verifyEq(r.typeof, TestRemoteRepo#)
    verifySame(r, r1)

    // verify bad ones
    verifyErr(Err#) { reg.add("foo bar", `http://foo-bar`, Etc.dict0) }
    verifyErr(Err#) { reg.add(n1, `http://foo-bar`, Etc.dict0) }
    verifyErr(Err#) { reg.add("fooBar", u1, Etc.dict0) }

    // verify saved config, reload and verify again
    verifyEq(config.exists, true)
    initEnv
    r1 = verifyRemote(n1, u1, m1)

    // now add another one
    n2 := "test2"
    u2  := `http://test-2/`
    m2 := Etc.dict1("ts", DateTime.now)
    r2 := reg.add(n2, u2, m2)
    r = verifyRemote(n2, u2, m2)
    verifyEq(r.typeof, TestRemoteRepo#)
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
    verifyEq(r.uri, `local:`)
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

//////////////////////////////////////////////////////////////////////////
// Network calls
//////////////////////////////////////////////////////////////////////////

  Void testCalls()
  {
    initEnv
    r := reg.add("test", `http://test-1/foo/bar`, Etc.dict0)
    verifyEq(r.typeof, TestRemoteRepo#)

    verifyDictEq(r.ping, Etc.dict1("ping", "boom!"))

    verifySearch(r, RemoteRepoSearchReq("alpha"),
      [["alpha", "1.0.1"],
       ["alpha", "1.0.2"],
       ["alpha", "1.1.0"],
       ["alpha", "1.1.9"],
       ["alpha", "1.2.0"],
       ["alpha", "2.0.0"],
       ["alpha", "2.3.0"]]
       )
  }

  Void verifySearch(RemoteRepo r, RemoteRepoSearchReq req, Obj[][] expect)
  {
    res := r.search(req)
    actual := res.libs
    verifyEq(actual.size, expect.size)
    actual.each |a, i|
    {
      e := expect[i]
      verifyEq(a.name,         e[0])
      verifyEq(a.version.toStr, e[1])
    }
  }

//////////////////////////////////////////////////////////////////////////
// Install
//////////////////////////////////////////////////////////////////////////

  Void testInstall()
  {
    initEnv
    remote = reg.add("test", `http://test-1/foo/bar`, Etc.dict0)

    verifyLibNotInstalled("alpha")
    verifyLibNotInstalled("beta")
    verifyLibNotInstalled("charlie")

    // simple plan with one lib, no depends
    inst := LibInstaller(env).install(remote, [LibDepend("alpha")])
    verifyPlan(inst,
      """i alpha null -> 2.3.0 test
         """)

    // simple plan with one lib and constraints
    c1xx := LibDependVersions("1.x.x")
    inst = LibInstaller(env).install(remote, [LibDepend("alpha", c1xx)])
    verifyPlan(inst,
      """i alpha null -> 1.2.0 test
         """)

    // simple plan with two libs, no depends
    inst = LibInstaller(env).install(remote, [LibDepend("alpha"), LibDepend("delta")])
    verifyPlan(inst,
      """i alpha null -> 2.3.0 test
         i delta null -> 4.0.0 test
         """)

    // one plan with direct depends
    inst = LibInstaller(env).install(remote, [LibDepend("beta")])
    verifyPlan(inst,
      """i alpha null -> 2.3.0 test transitive
         i beta null -> 2.0.1 test
         """)

    // one plan with multiple transitive depends
    inst = LibInstaller(env).install(remote, [LibDepend("charlie")])
    verifyPlan(inst,
      """i alpha null -> 1.1.9 test transitive
         i beta null -> 1.1.0 test transitive
         i charlie null -> 2.0.1 test
         """)

    // verify unsolvable plans
    verifyUnsolvable("Lib 'sys' already installed (run update)") { LibInstaller(env).install(remote, [LibDepend("sys")]) }
    verifyUnsolvable("Lib 'ph' already installed (run update)") { LibInstaller(env).install(remote, [LibDepend("ph")]) }
    verifyUnsolvable("Install requires upgrade to 'ph.points' (run with -upgrade flag)") { LibInstaller(env).install(remote, [LibDepend("echo")]) }
    verifyUnsolvable("No origin for 'ph.points' that requires update") { LibInstaller(env, Etc.dict1("upgrade", m)).install(remote, [LibDepend("echo")]) }
    verifyUnsolvable("Install requires upgrade to 'sys' (run with -upgrade flag)") { LibInstaller(env).install(remote, [LibDepend("bad.a")]) }
    verifyUnsolvable("Install requires upgrade to 'sys' (run with -upgrade flag)") { LibInstaller(env).install(remote, [LibDepend("bad.b")]) }
    verifyUnsolvable("Unresolved dependency 'notfound x.x.x' in repo 'test'") { LibInstaller(env).install(remote, [LibDepend("bad.c")]) }
    verifyUnsolvable("Unresolved dependency 'bad.c 9.0.0' in repo 'test'") { LibInstaller(env).install(remote, [LibDepend("bad.d")]) }
    verifyUnsolvable("Unresolved dependency 'whatitis x.x.x' in repo 'test'") { LibInstaller(env).install(remote, [LibDepend("whatitis")]) }

    // ok lets run the install beta (+alpha) plan
    c11x := LibDependVersions("1.1.x")
    inst = LibInstaller(env).install(remote, [LibDepend("beta", c11x)])
    verifyPlan(inst,
      """i alpha null -> 1.1.9 test transitive
         i beta null -> 1.1.0 test
         """)
    inst.execute
    verifyLibInstalled("alpha", "1.1.9")
    verifyLibInstalled("beta", "1.1.0")

    // now lets upgrade beta
    c2xx := LibDependVersions("2.x.x")
    inst = LibInstaller(env).update([LibDepend("beta", c2xx)])
    verifyPlan(inst,
      """u alpha 1.1.9 -> 2.3.0 test transitive
         u beta 1.1.0 -> 2.0.1 test
         """)
    inst.execute
    verifyLibInstalled("alpha", "2.3.0")
    verifyLibInstalled("beta", "2.0.1")
  }

  Void verifyPlan(LibInstaller inst, Str expect)
  {
    debug := false
    if (debug)
    {
      echo
      echo("### verifyPlan ###")
      inst.planDump
    }

    lines := expect.trim.splitLines
    lines.each |e, i|
    {
      p := inst.plan[i]
      a := p.action.name[0..0] + " " + p.name + " " +
           p.curVer?.version + " -> " + p.newVer?.version + " " + p.repo
      if (p.transitive) a += " transitive"
      if (debug)
      {
        echo("--> $e")
        echo("  > $a")
      }
      verifyEq(a, e)
    }
    verifyEq(lines.size, inst.plan.size)
  }

  Void verifyLibNotInstalled(Str n)
  {
    local := XetoEnv.cur.repo
    verifyEq(local.lib(n, false), null)
    verifyEq(local.libs.find { it.name == n }, null)
  }

  Void verifyLibInstalled(Str n, Str v)
  {
    xf := env.workDir + `lib/xeto/${n}.xetolib`
    verifyEq(xf.exists, true)

    of := env.workDir + `lib/xeto/${n}-origin.props`
    verifyEq(of.exists, true)
    // echo(of.readProps)

    // verify lib basics
    lib := env.repo.lib(n)
    verifyEq(lib.name, n)
    verifyEq(lib.version.toStr, v)
    verifyEq(lib.file.parent, env.workDir + `lib/xeto/`)

    // verify origin
    o := lib.origin
    verifyEq(o.repoName, remote.name)
    verifyEq(o.uri, remote.uri)
    verifyEq(o.fetched.date, Date.today)
    verifyEq(o.meta->fetched, o.fetched)
    verifySame(o.meta->uri, o.uri)
    verifySame(o.meta->repo, o.repoName)
  }

  Void verifyUnsolvable(Str msg, |Test->LibInstaller| f)
  {
    verifyErrMsg(InstallPlanErr#, msg)
    {
      inst := f(this)
      inst.planDump
    }
  }

  RemoteRepo? remote
}

**************************************************************************
** TestRemoteRepo
**************************************************************************

const class TestRemoteRepo : MRemoteRepo
{
  new make(RemoteRepoInit init) : super(init) {}

  override Dict? ping(Bool checked := true) { Etc.dict1("ping", "boom!") }

  override RemoteRepoSearchRes search(RemoteRepoSearchReq req)
  {
    matches := testLibs.findAll { req.matches(it) }
    return MRemoteRepoSearchRes { it.libs = matches }
  }

  override LibVersion[] versions(Str name, Dict? opts := null)
  {
    list := testLibs.findAll { it.name == name }
    list = list.dup.sortr
    return findAllVersionsWithOpts(list, opts)
  }

  LibVersion[] testLibs()
  {
    [lib("alpha",   "1.0.1", "sys"),
     lib("alpha",   "1.0.2", "sys"),
     lib("alpha",   "1.1.0", "sys"),
     lib("alpha",   "1.1.9", "sys"),
     lib("alpha",   "1.2.0", "sys"),
     lib("alpha",   "2.0.0", "sys"),
     lib("alpha",   "2.3.0", "sys"),

     lib("beta",    "1.0.1", "sys, sys.comp, alpha-1.0.1"),
     lib("beta",    "1.0.2", "sys, sys.comp, alpha-1.0.2"),
     lib("beta",    "1.1.0", "sys, sys.comp, alpha-1.1.x"),
     lib("beta",    "1.2.0", "sys, sys.comp, alpha-1.2.0"),
     lib("beta",    "2.0.0", "sys, sys.comp, alpha-2.0.0"),
     lib("beta",    "2.0.1", "sys, sys.comp, alpha-2.x.x"),

     lib("charlie", "1.0.1", "sys, ph, beta-1.1.x"),
     lib("charlie", "2.0.1", "sys, ph, beta-1.1.x"),

     lib("delta",   "4.0.0", "sys, ph.points"),

     lib("echo",     "4.0.0", "sys, ph.points-7.x.x"),

     lib("ph.points", "7.0.1", "sys"),
     lib("ph.points", "7.0.2", "sys"),
     lib("ph.points", "7.0.3", "sys"),

     lib("bad.a",   "4.0.0", "sys-6.x.x"),
     lib("bad.b",   "4.0.0", "bad.a"),
     lib("bad.c",   "4.0.0", "notfound"),
     lib("bad.d",   "4.0.0", "bad.c-9.0.0"),
    ]
  }

  override Buf fetch(Str name, Version version)
  {
    buf := Buf()
    zip := Zip.write(buf.out)
    zip.writeNext(`/meta.props`)
       .printLine("name=$name")
       .printLine("version=$version")
       .printLine("doc=Test it!")
       .printLine("depends=sys x.x.x")
       .close
    zip.close
    return buf.toImmutable
  }

  LibVersion lib(Str n, Str v, Str depends := "")
  {
    d := depends.split(',').map |dx->LibDepend|
    {
      toks := dx.split('-')
      dn := toks[0]
      dc := toks.getSafe(1) ?: LibDependVersions.wildcard.toStr
      return LibDepend(dn, LibDependVersions(dc))
    }
    return RemoteLibVersion(n, Version(v), "blah", d)
  }
}

