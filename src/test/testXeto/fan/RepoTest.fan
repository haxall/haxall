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
@Js
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
// Solve Depends
//////////////////////////////////////////////////////////////////////////

  Void testSolveDepends()
  {
    repo := LibRepo.cur
    sys := repo.latest("sys")
    verifyEq(sys.depends, MLibDepend[,])
    libs := repo.solveDepends([repo.latest("sys")])
    verifyEq(libs.size, 1)
    verifySame(libs[0], sys)
  }
}

