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

  @HxTestProj
  Void testLibRepoAddRemove()
  {
    addLib("hx.repo")

    // add a new repo
    Dict added := eval("""libRepoAdd("testrepo", `https://example.com/xeto`)""")
    verifyEq(added["name"], "testrepo")
    verifyEq(added["uri"],  `https://example.com/xeto`)

    // verify it shows up in list
    Grid grid := eval("libRepos()")
    row := grid.find { it->name == "testrepo" } ?: throw Err()
    verifyEq(row["name"], "testrepo")
    verifyEq(row["uri"],  `https://example.com/xeto`)

    // remove
    Str removed := eval("""libRepoRemove("testrepo")""")
    verifyEq(removed, "removed")

    // verify it's gone
    grid = eval("libRepos()")
    verifyEq(grid.find { it->name == "testrepo" }, null)
  }

  @HxTestProj
  Void testLibRepoLoginLogout()
  {
    addLib("hx.repo")

    // login sets auth token
    Str envName := eval("""libRepoLogin("xetodev", "test-token-123")""")
    verify(envName.contains("XETO_REPO"))

    // verify token shows in repo list
    Grid grid := eval("libRepos()")
    xetodev := grid.find { it->name == "xetodev" } ?: throw Err()
    verifyNotNull(xetodev["authToken"])

    // logout clears auth token
    envName = eval("""libRepoLogout("xetodev")""")
    verify(envName.contains("XETO_REPO"))
  }

}
