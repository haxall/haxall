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
        verifySame(repo.version(lib, v.version), v)
      }
      verifySame(versions.last, repo.latest(lib))
    }
  }

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

