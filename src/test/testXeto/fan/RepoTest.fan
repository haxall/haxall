//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using util
using xeto
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
echo("-- $v")
    verifyEq(v.name, name)
    verifyEq(v.version.segments.size, 3)
echo("   $v.depends")
  }

//////////////////////////////////////////////////////////////////////////
// Solve Depends
//////////////////////////////////////////////////////////////////////////

  Void testSolveDepends()
  {
    repo := LibRepo.cur
    sys := repo.latest("sys")
    verifyEq(sys.depends, LibDepend[,])
    libs := repo.solveDepends([repo.latest("sys")])
    verifyEq(libs.size, 1)
    verifySame(libs[0], sys)
  }
}

