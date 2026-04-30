//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using util
using xeto
using xetom
using xetoc
using haystack

**
** RepoTest
**
class RepoTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    repo := XetoEnv.cur.repo
    verifySame(repo, XetoEnv.cur.repo)

    libs := repo.libs
    verifySame(repo.libs, libs)
    libs.each |lib|
    {
      verifySame(lib, repo.lib(lib.name))
    }
  }

  Void verifyVersion(LibRepo repo, Str name, LibVersion v)
  {
    /*
    echo
    echo("-- $v")
    echo("   name:    $v.name")
    echo("   version: $v.version")
    echo("   doc:     $v.doc")
    echo("   depends: $v.depends")
    echo("   file:    $v.file")
    echo("   sysOnly: $v.isSysOnly")
    echo
    */

    verifyEq(v.name, name)
    verifyEq(v.version.segments.size, 3)

    // spot test known libs
    if (name == "sys")
    {
      verifyEq(v.doc, "System library of built-in types")
      verifyEq(v.depends.size, 0)
      verifyEq(v.isHxSysOnly, false)
    }
    else if (name == "ph")
    {
      verifyEq(v.doc, "Project haystack core library")
      verifyEq(v.depends.size, 1)
      verifyEq(v.depends[0].name, "sys")
      verifyEq(v.isHxSysOnly, false)
    }
    else if (name == "hx.crypto")
    {
      verifyEq(v.isHxSysOnly, true)
    }
    else if (name == "hx.http")
    {
      verifyEq(v.isHxSysOnly, true)
    }
    else if (name == "hx.conn")
    {
      verifyEq(v.isHxSysOnly, false)
    }
    else if (name == "hx.task")
    {
      verifyEq(v.isHxSysOnly, false)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Check Depends
//////////////////////////////////////////////////////////////////////////

  Void testCheckDepends()
  {
    repo := buildTestRepo

    verifyCheckDepends(repo, "sys")
    verifyCheckDepends(repo, "sys, ph")
    verifyCheckDepends(repo, "sys, ph, ph.points")
    verifyCheckDepends(repo, "sys, ph, ph.points, cc.vavs")
    verifyCheckDepends(repo, "sys, ph, ph.points, cc.ahus, cc.vavs")

    verifyCheckDepends(repo, "sys, ph, ph.points, cc.ahus, cc.notfound", [
      "cc.notfound":UnknownLibErr("Lib 'cc.notfound' not found")
      ])

    verifyCheckDepends(repo, "sys, ph, ph.points, cc.ahus, cc.nosolve", [
      "cc.nosolve":DependErr("Lib 'cc.nosolve' has missing depends: ph 9.x.x")
      ])

    verifyCheckDepends(repo, "sys, ph, ph.points, cc.ahus, cc.nosolven", [
      "cc.nosolven":DependErr("Lib 'cc.nosolven' has missing depends: bar, foo, ph 9.x.x, qux")
      ])

    verifyCheckDepends(repo, "sys, ph, ph.points, cc.ahus, cc.circular", [
        "cc.circular":DependErr("Lib 'cc.circular' has circular depends")
      ])

    verifyCheckDepends(repo, "sys, ph, ph.points, cc.ahus, cc.circular, cc.missing1, cc.missing2, cc.nosolve, cc.nosolven", [
        "cc.circular": DependErr("Lib 'cc.circular' has circular depends"),
        "cc.missing1": UnknownLibErr("Lib 'cc.missing1' not found"),
        "cc.missing2": UnknownLibErr("Lib 'cc.missing2' not found"),
        "cc.nosolve":  DependErr("Lib 'cc.nosolve' has missing depends: ph 9.x.x"),
        "cc.nosolven": DependErr("Lib 'cc.nosolven' has missing depends: bar, foo, ph 9.x.x, qux"),
      ])
  }

  Void verifyCheckDepends(LocalRepo repo, Str names, Str:Err expectErrs := [:])
  {
    LibVersion[] libs := names.split(',').map |x->LibVersion|
    {
      repo.lib(x, false) ?: FileLibVersion.makeNotFound(x)
    }

    (libs.size * 2).times
    {
      shuffled := libs.dup.shuffle

      // LibVersion.checkDepends
      errs := Str:Err[:]
      ordered := LibVersion.checkDepends(shuffled, errs)
      // echo("~~~ $names errs=$errs.size"); echo(errs.join("\n"))
      verifyEq(ordered.join(", ") { it.name }, names)
      verifyEq(errs.size, expectErrs.size)
      expectErrs.each |expect, name|
      {
        actual := errs[name] ?: throw Err("checkDepend missing err: $name")
        verifyEq(actual.toStr, expect.toStr)
      }

      // LibVersion.orderByDepends returns same thing or raises exception
      try
      {
        ordered = LibVersion.orderByDepends(shuffled)
        verifyEq(ordered.join(", ") { it.name }, names)
        if (!errs.isEmpty) fail
      }
      catch (Err e)
      {
        if (errs.isEmpty) fail
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Solve Depends
//////////////////////////////////////////////////////////////////////////

  Void testSolveDepends()
  {
    repo := buildTestRepo
    // repo.dump

    // just sys

    verifySolveDepends(repo,
      "sys 1.0.x",
      "sys 1.0.3")

    verifySolveDepends(repo,
      "sys 1.1.x",
      "sys 1.1.4")

    verifySolveDepends(repo,
      "sys 2.x.x",
      "sys 2.0.6")

    // just ph

    verifySolveDepends(repo,
      "ph 2.x.x",
      "sys 2.0.6, ph 2.0.8")

    // cc.vavs

    verifySolveDepends(repo,
      "sys 2.x.x, ph 2.x.x, ph.points 2.x.x, cc.vavs 20.x.x",
      "sys 2.0.6, ph 2.0.8, ph.points 2.0.208, cc.vavs 20.0.20")

    // errors
    verifySolveDependsErr(repo,
      "sys 4.x.x",
      "Target dependency: sys 4.x.x [not found]")

    verifySolveDependsErr(repo,
      "sys 3.x.x, foo.bar 1.2.3",
      "Target dependency: foo.bar 1.2.3 [not found]")

    verifySolveDependsErr(repo,
      "cc.vavs 20.x.x",
      "ph.points dependency: ph 2.0.8 [ph-3.0.9]")
  }

  Void verifySolveDepends(LocalRepo repo, Str targetsStr, Str expectStr)
  {
    targets := depends(targetsStr)
    expects := expectStr.split(',').sort
    // echo; echo("== verifySolveDepends: $targets")
    actuals := repo.resolveDepends(targets)
                .sort |a, b| { a.name <=> b.name }
                .map |x->Str| { "$x.name $x.version" }
    verifyEq(actuals, expects)
  }

  Void verifySolveDependsErr(LocalRepo repo, Str targetsStr, Str expect)
  {
    targets := depends(targetsStr)
    // echo; echo("== verifySolveDependsErr: $targets")
    verifyErrMsg(DependErr#, expect) { repo.resolveDepends(targets) }
  }

//////////////////////////////////////////////////////////////////////////
// Namespace
//////////////////////////////////////////////////////////////////////////

  Void testNamespace()
  {
    // need fresh ns
    env := ServerEnv.initPath
    repo := env.repo

    //
    // sys only
    //
    LibVersion sysVer := repo.lib("sys")
    ns := env.createNamespace([sysVer])
    sysNs := ns
    verifyEq(ns.versions, [sysVer])
    verifySame(ns.version("sys"), sysVer)
    verifyEq(ns.libStatus("sys"), LibStatus.ok)
    verifyEq(ns.hasLib("sys"), true)
    verifyEq(ns.hasLib("ph"), false)
    verifyEq(ns.hasLib("foo.bad.one"), false)
    verifySame(ns.digest, ns.digest)

    sys := ns.lib("sys")
    verifySame(ns.lib("sys"), sys)
    verifySame(ns.sysLib, sys)
    verifyEq(sys.name, "sys")
    verifyEq(sys.version, sysVer.version)
    verifyEq(ns.libs, Lib[sys])
    verifySame(ns.libs, ns.libs)

    files := File[,]
    sysVer.eachSrcFile |f| { files.add(f) }
    fileNames := files.sort.join(",") { it.name }
    verifyEq(fileNames, "lib.xeto,libmeta.xeto,spec.xeto,timezones.xeto,types.xeto,units.xeto")


    //
    // sys and ph
    //
    LibVersion phVer := repo.lib("ph")
    ns = env.createNamespace([phVer, sysVer])
    verifySame(ns.digest, ns.digest)
    verifyNotEq(sysNs.digest, ns.digest)
    verifyEq(ns.versions, [sysVer, phVer])
    verifySame(ns.version("sys"), sysVer)
    verifyEq(ns.libStatus("sys"), LibStatus.ok)
    verifySame(ns.version("ph"), phVer)
    verifyEq(ns.hasLib("sys"), true)
    verifyEq(ns.hasLib("ph"), true)
    verifyEq(ns.hasLib("foo.bad.one"), false)
    sys = ns.lib("sys")

    verifyEq(ns.lib("foo.bar.baz", false), null)
    verifyErr(UnknownLibErr#) { ns.lib("foo.bar.baz") }
    verifyErr(UnknownLibErr#) { ns.lib("foo.bar.baz", true) }

    ph := ns.lib("ph")
    verifyEq(ns.libStatus("ph"), LibStatus.ok)
    verifySame(ns.lib("ph"), ph)
    verifyEq(ph.name, "ph")
    verifyEq(ph.version, phVer.version)
    verifyEq(ns.libs, Lib[sys, ph])
    verifySame(ns.libs, ns.libs)

    verifySame(ns.spec("sys::Str").lib, ns.sysLib)
    verifySame(ns.type("ph::Point").lib, ph)
    verifySame(ns.spec("ph::Point.point").lib, ph)
  }

//////////////////////////////////////////////////////////////////////////
// FileRepo
//////////////////////////////////////////////////////////////////////////

  Void testFileRepo()
  {
/*
    tempDir := this.tempDir.normalize
    path := Env.cur.path.dup.insert(0, tempDir)
    env := ServerEnv("test", path)
    verifyEq(env.workDir, tempDir)
    verifyEq(env.installDir, tempDir)

    // now generate lots of versions of a fake lib:
    //   3.0.74 - 3.0.70
    //   2.0.64 - 2.0.60
    //   1.0.54 - 1.0.50
    versions := Version[,]
    for (i := 1; i<4; ++i)
      for (j := i*10+40; j<i*10+45; ++j)
        versions.add(Version([i, 0, j]))

    n := "fake"
    versions.each |v| { genFakeLib(env.workDir, n, v) }

    repo := env.repo

    // verify sorted oldest to newest
    all := repo.lib(n)
    // echo(all.join("\n"))
    versions.sortr
    verifyEq(all.first.version, versions.first)
    verifyEq(all.last.version, versions.last)

    // version for each one
    versions.each |v|
    {
      x := repo.version(n, v)
      verifyEq(x.name, n)
      verifyEq(x.version, v)
    }

    // limits
    verifyRepoLimit(repo, n, 1, all[0..0])
    verifyRepoLimit(repo, n, 2, all[0..1])
    verifyRepoLimit(repo, n, 3, all[0..2])
    verifyRepoLimit(repo, n, 100, all)

    // constraints
    verifyRepoConstraints(repo, n, "x.x.x", null, all)
    verifyRepoConstraints(repo, n, "3.x.x", null, all[0..4])
    verifyRepoConstraints(repo, n, "2.x.x", null, all[5..9])
    verifyRepoConstraints(repo, n, "2.x.x", 1, all[5..5])
    verifyRepoConstraints(repo, n, "2.x.x", 2, all[5..6])

    // latest
    verifySame(repo.latest(n), all.first)

    // lastestMatch
    verifyRepoLatestMatch(repo, n, "x.x.x",  all.first)
    verifyRepoLatestMatch(repo, n, "3.0.72", all.find { it.version.toStr == "3.0.72" })
    verifyRepoLatestMatch(repo, n, "3.0.x",  all.find { it.version.toStr == "3.0.74" })
    verifyRepoLatestMatch(repo, n, "2.0.x",  all.find { it.version.toStr == "2.0.64" })
    verifyRepoLatestMatch(repo, n, "3.1.x",  null)

    // bad lib
    bad := "badOne"
    verifyEq(repo.latest(bad, false), null)
    verifyErr(UnknownLibErr#) { repo.latest(bad) }
    verifyErr(UnknownLibErr#) { repo.latest(bad, true) }
    verifyRepoLatestMatch(repo, bad, "x.x.x", null)
    verifyRepoConstraints(repo, bad, "x.x.x", null, LibVersion[,])
  }

  Void verifyRepoLimit(LibRepo repo, Str n, Int limit, LibVersion[] expect)
  {
    actual := repo.versions(n, Etc.dict1("limit", limit))
    verifyEq(actual, expect)

    actual = repo.versions(n, Etc.dict1("limit", Number(limit)))
    verifyEq(actual, expect)
  }

  Void verifyRepoConstraints(LibRepo repo, Str n, Str constraints, Int? limit, LibVersion[] expect)
  {
    actual := repo.versions(n, Etc.dict2x("versions", LibDependVersions(constraints), "limit", limit))
    verifyEq(actual, expect)

    actual = repo.versions(n, Etc.dict2x("versions", constraints, "limit", limit))
    verifyEq(actual, expect)
  }

  Void verifyRepoLatestMatch(LibRepo repo, Str n, Str constraints, LibVersion? expect)
  {
    c := LibDepend(n, LibDependVersions(constraints))
    actual := repo.latestMatch(c, false)
    verifySame(actual, expect)
    if (expect == null)
    {
      verifyErr(UnknownLibErr#) { repo.latestMatch(c) }
      verifyErr(UnknownLibErr#) { repo.latestMatch(c, true) }
    }
  }

  Void genFakeLib(File dir, Str n, Version v)
  {
    f := dir + `lib/xeto/${n}/${n}-${v}.xetolib`
    f.out.print("fake").close
*/
  }

//////////////////////////////////////////////////////////////////////////
// Test Repo
//////////////////////////////////////////////////////////////////////////

  internal TestLocalRepo buildTestRepo()
  {
    testRepoMap = Str:TestLibVersion[][:]

    testLibName = "sys"
    addVer("1.0.3", "")
    addVer("1.1.4", "")
    addVer("2.0.5", "")
    addVer("2.0.6", "")
    addVer("3.0.7", "")

    testLibName = "ph"
    addVer("1.0.7", "sys 1.0.x")
    addVer("2.0.8", "sys 2.x.x")
    addVer("3.0.9", "sys 3.x.x")

    testLibName = "ph.points"
    addVer("1.0.107", "sys 1.x.x, ph 1.0.7")
    addVer("1.0.207", "sys 1.x.x, ph 1.0.7")
    addVer("2.0.108", "sys x.x.x, ph 2.0.8")
    addVer("2.0.208", "sys x.x.x, ph 2.0.8")
    addVer("3.0.309", "sys x.x.x, ph x.x.x")

    testLibName = "cc.vavs"
    addVer("10.0.10", "sys x.x.x, ph x.x.x, ph.points 1.x.x")
    addVer("20.0.20", "sys x.x.x, ph x.x.x, ph.points 2.x.x")
    addVer("30.0.30", "sys x.x.x, ph x.x.x, ph.points x.x.x")

    testLibName = "cc.ahus"
    addVer("10.0.10", "sys x.x.x, ph x.x.x, ph.points 1.x.x")
    addVer("20.0.20", "sys x.x.x, ph x.x.x, ph.points x.x.x")

    testLibName = "cc.circular"
    addVer("10.0.10", "sys x.x.x, ph x.x.x, cc.circular x.x.x")

    testLibName = "cc.nosolve"
    addVer("10.0.10", "sys x.x.x, ph 9.x.x")

    testLibName = "cc.nosolven"
    addVer("10.0.10", "sys x.x.x, ph 9.x.x, foo x.x.x, bar x.x.x, qux x.x.x")

    return TestLocalRepo(XetoEnv.cur, testRepoMap)
  }

  private [Str:TestLibVersion[]]? testRepoMap

  private Str? testLibName

  private TestLibVersion addVer(Str v, Str d)
  {
    x := TestLibVersion(testLibName, Version(v), depends(d))
    list := testRepoMap[x.name]
    if (list == null) testRepoMap[x.name] = list = TestLibVersion[,]
    list.add(x)
    list.sort |a, b| { a.version <=> b.version }
    return x
  }

  private LibDepend[] depends(Str s)
  {
    if (s.isEmpty) return LibDepend[,]
    return s.split(',').map |str->LibDepend| { depend(str) }
  }

  private LibDepend depend(Str s)
  {
    toks := s.split
    return LibDepend(toks[0], LibDependVersions(toks[1]))
  }
}

**************************************************************************
** TestLocalRepo
**************************************************************************

** This guy stores multiple versions of each repo to maintain
** the multi-version test suite for dependency solver
internal const class TestLocalRepo : MLocalRepo
{
  new make(MEnv env, Str:TestLibVersion[] map) : super(env) { this.map = map }

  override This rescan() { this }

  override LibVersion[] libs()
  {
    map.keys.sort.map |n->LibVersion| { lib(n) }
  }

  override LibVersion? lib(Str n, Bool checked := true)
  {
    list := versions(n)
    if (list != null) return list.first
    if (checked) throw UnknownLibErr(n)
    return null
  }

  override LibVersion? depend(LibDepend d, Bool checked := true)
  {
    list := versions(d.name)
    if (list != null)
    {
      match := list.dup.sortr.find { d.versions.contains(it.version) }
      if (match != null) return match
    }
    if (checked) throw UnknownLibErr(d.toStr)
    return null
  }

  override LibVersion[] resolveDepends(LibDepend[] libs)
  {
    DependSolver(this, libs).solve
  }

  LibVersion[]? versions(Str n)
  {
    // list newest to oldest
    list := map[n]
    if (list == null) return null
    return list.dup.sortr
  }

  Void dump()
  {
    libs.each |lib|
    {
      vers := map.get(lib.name)
      echo("-- $lib [$vers.size versions]")
      vers.each |v| { echo("   $v.version $v.depends") }
    }
  }

  const Str:TestLibVersion[] map
}

**************************************************************************
** TestLibVersion
**************************************************************************

internal const class TestLibVersion : LibVersion
{
  new make(Str n, Version v, LibDepend[] d) { name = n; version = v; dependsRef = d }
  override const Str name
  override const Version version
  override LibDepend[]? depends(Bool checked := true) { dependsRef }
  const LibDepend[] dependsRef
  override LibOrigin? origin(Bool checked := true) { null }
  override Str doc() { "" }
  override Bool isSrc() { false }
  override Int flags() { 0 }
  override Void eachSrcFile(|File| f) {}
  override File? file(Bool checked := true) { throw UnsupportedErr() }
  override Str toStr() { "$name-$version" }
  override Bool isNotFound() { false }
  override Bool isCompanion() { name == XetoUtil.companionLibName }
}

