//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Apr 2024  Brian Frank  Creation
//

using xeto
using haystack

**
** DependSolver impplements LibRepo.solveDepends.  A proper solver
** can be very expensive, so this is implementation just tries to
** select against latest matching version for each dependency and if
** it doesn't work then it gives up.
**
class DependSolver
{
  new make(LibRepo repo, LibDepend[] targets)
  {
    this.repo    = repo
    this.targets = targets
  }

  LibVersion[] solve()
  {
    targets.each |target|
    {
      solveDepend("Target", target)
    }
    return acc.vals
  }

  private Void solveDepend(Str who, LibDepend d)
  {
    // check if we have already selected a version for this lib name
    x := acc[d.name]

    // if we have not, then find the latest version available that matches
    if (x == null)
    {
      x = repo.latestMatch(d, false) ?: throw DependErr("$who dependency: $d.toStr [not found]")
      acc[x.name] = x
    }

    // otherwise make sure that one we selected is a match
    else
    {
      if (!d.versions.contains(x.version)) throw DependErr("$who dependency: $d.toStr [$x]")
    }

    // now recursively ensure all the dependencies are added
    x.depends.each |sub| { solveDepend(x.name, sub) }
  }

  const LibRepo repo
  private LibDepend[] targets
  private Str:LibVersion acc := [:]
}

