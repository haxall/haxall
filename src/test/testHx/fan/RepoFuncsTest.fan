//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 May 2026  Trevor Adelman  Creation
//

using xeto
using haystack
using axon
using hx

**
** RepoFuncsTest
**
class RepoFuncsTest : HxTest
{

  @HxTestProj
  Void testLibRepos()
  {
    addLib("hx.repo")

    // list repos
    Grid grid := eval("libRepos()")
    verify(grid.size >= 2)

    // verify xetodev (default repo)
    xetodev := grid.find { it->name == "xetodev" } ?: throw Err()
    verifyEq(xetodev["name"], "xetodev")
    verifyEq(xetodev["uri"],  `https://xeto.dev/`)

    // verify cc repo
    cc := grid.find { it->name == "cc" } ?: throw Err()
    verifyEq(cc["name"], "cc")
    verifyEq(cc["uri"],  `https://github.com/Project-Haystack/xeto-cc`)
  }

}
