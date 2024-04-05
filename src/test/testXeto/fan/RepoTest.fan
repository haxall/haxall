//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack
using haystack::Ref

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
    repo := LibRepo.cur
    verifySame(repo, LibRepo.cur)

    libs := repo.libs
    verifySame(repo.libs, libs)
    libs.each |lib|
    {
      versions := repo.versions(lib)
      versions.each |v|
      {
        verifyVersion(repo, lib, v)
      }
      verifySame(versions.last, repo.latest(lib))
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
    echo
    */
    verifyEq(v.name, name)
    verifyEq(v.version.segments.size, 3)

    // spot test known libs
    if (name == "sys")
    {
      verifyEq(v.doc, "System library of built-in types")
      verifyEq(v.depends.size, 0)
    }
    else if (name == "ph")
    {
      verifyEq(v.doc, "Project haystack core library")
      verifyEq(v.depends.size, 1)
      verifyEq(v.depends[0].name, "sys")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Order Depends
//////////////////////////////////////////////////////////////////////////

  Void testOrderByDepends()
  {
    repo := buildTestRepo

    verifyOrderByDepends(repo, "sys")
    verifyOrderByDepends(repo, "sys, ph")
    verifyOrderByDepends(repo, "sys, ph, ph.points")
    verifyOrderByDepends(repo, "sys, ph, ph.points, cc.vavs")
    verifyOrderByDepends(repo, "sys, ph, ph.points, cc.ahus, cc.vavs")

    verifyErrMsg(DependErr#, "Circular depends")
    {
      verifyOrderByDepends(repo, "sys, ph, ph.points, cc.ahus, cc.circular")
    }

    verifyErrMsg(DependErr#, "cc.noSolve-10.0.10 dependency: ph 9.x.x [ph-3.0.9]")
    {
      verifyOrderByDepends(repo, "sys, ph, ph.points, cc.ahus, cc.noSolve")
    }
  }

  Void verifyOrderByDepends(LibRepo repo, Str names)
  {
    LibVersion[] libs := names.split(',').map |x->LibVersion| { repo.latest(x) }
    (libs.size * 2).times
    {
      shuffled := libs.dup.shuffle
      sorted := LibVersion.orderByDepends(shuffled)
      sortedNames := sorted.join(", ") { it.name }
      // echo("~~> " + shuffled.join(", ") { it.name })
      // echo("  > $sortedNames")
      verifyEq(sortedNames, names)
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

  Void verifySolveDepends(LibRepo repo, Str targetsStr, Str expectStr)
  {
    targets := depends(targetsStr)
    expects := expectStr.split(',').sort
    // echo; echo("== verifySolveDepends: $targets")
    actuals := repo.solveDepends(targets)
                .sort |a, b| { a.name <=> b.name }
                .map |x->Str| { "$x.name $x.version" }
    verifyEq(actuals, expects)
  }

  Void verifySolveDependsErr(LibRepo repo, Str targetsStr, Str expect)
  {
    targets := depends(targetsStr)
    // echo; echo("== verifySolveDependsErr: $targets")
    verifyErrMsg(DependErr#, expect) { repo.solveDepends(targets) }
  }

//////////////////////////////////////////////////////////////////////////
// Namespace
//////////////////////////////////////////////////////////////////////////

  Void testNamespace()
  {
    //
    // sys only
    //
    repo := LibRepo.cur
    LibVersion sysVer := repo.latest("sys")
    ns := repo.createNamespace([sysVer])
    verifyEq(ns.versions, [sysVer])
    verifySame(ns.version("sys"), sysVer)
    verifyEq(ns.isLoaded("sys"), true)
    verifyEq(ns.isAllLoaded, true)

    sys := ns.lib("sys")
    verifySame(ns.lib("sys"), sys)
    verifySame(ns.sysLib, sys)
    verifyEq(sys.name, "sys")
    verifyEq(sys.version, sysVer.version)

    //
    // sys and ph
    //
    LibVersion phVer := repo.latest("ph")
    ns = repo.createNamespace([phVer, sysVer])
    verifyEq(ns.versions, [sysVer, phVer])
    verifySame(ns.version("sys"), sysVer)
    verifyEq(ns.isLoaded("sys"), true)
    verifySame(ns.version("ph"), phVer)
    verifyEq(ns.isAllLoaded, false)
    verifyNotSame(ns.sysLib, sys)  // new compile of sys
    verifyNotSame(ns.lib("sys"), sys)

    verifyEq(ns.lib("foo.bar.baz", false), null)
    verifyErr(UnknownLibErr#) { ns.lib("foo.bar.baz") }
    verifyErr(UnknownLibErr#) { ns.lib("foo.bar.baz", true) }
    asyncErr := null; asyncLib := null
    ns.libAsync("foo.bar.baz") |e,l| { asyncErr = e; asyncLib = l }
    verifyEq(asyncErr.typeof, UnknownLibErr#)
    verifyEq(asyncLib, null)

    verifyEq(ns.isLoaded("ph"), false)
    verifyEq(ns.lib("ph", false), null)
    verifyEq(ns.isLoaded("ph"), false)
    ph := ns.lib("ph")
    verifySame(ns.lib("ph"), ph)
    verifyEq(ph.name, "ph")
    verifyEq(ph.version, phVer.version)
    verifyEq(ns.isLoaded("ph"), true)
    verifyEq(ns.isAllLoaded, true)
    asyncErr = null; asyncLib = null
    ns.libAsync("ph") |e,l| { asyncErr = e; asyncLib = l }
    verifyEq(asyncErr, null)
    verifySame(asyncLib, ph)
  }

//////////////////////////////////////////////////////////////////////////
// Test Repo
//////////////////////////////////////////////////////////////////////////

  internal TestRepo buildTestRepo()
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

    testLibName = "cc.noSolve"
    addVer("10.0.10", "sys x.x.x, ph 9.x.x")

    return TestRepo(testRepoMap)
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
** TestRepo
**************************************************************************

internal const class TestRepo : LibRepo
{
  new make(Str:TestLibVersion[] map) { this.map = map }

  override This rescan() { this }

  override Str[] libs() { map.keys.sort }

  override LibVersion[]? versions(Str name, Bool checked := true)
  {
    versions := map.get(name)
    if (versions != null) return versions
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override LibVersion? latest(Str name, Bool checked := true)
  {
    versions := versions(name, checked)
    if (versions != null) return versions.last
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override LibVersion? latestMatch(LibDepend d, Bool checked := true)
  {
    versions := versions(d.name, checked)
    if (versions != null)
    {
      match := versions.eachrWhile |x| { d.versions.contains(x.version) ? x : null }
      if (match != null) return match
    }
    if (checked) throw UnknownLibErr(d.toStr)
    return null
  }

  override LibVersion? version(Str name, Version version, Bool checked := true)
  {
    x := versions(name, checked)?.find |x| { version == x.version }
    if (x != null) return x
    if (checked) throw UnknownLibErr("$name-$version")
    return null
  }

  override LibVersion[] solveDepends(LibDepend[] libs)
  {
    DependSolver(this, libs).solve
  }

  override LibNamespace createNamespace(LibVersion[] libs)
  {
    throw UnsupportedErr()
  }

  Void dump()
  {
    libs.each |lib|
    {
      vers := versions(lib)
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
  new make(Str n, Version v, LibDepend[] d) { name = n; version = v; depends = d }
  override const Str name
  override const Version version
  override const LibDepend[] depends
  override Str doc() { "" }
  override File? file(Bool checked := true) { throw UnsupportedErr() }
  override Str toStr() { "$name-$version" }
}

