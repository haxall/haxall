//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 May 2026  Trevor Adelman  Creation
//

using concurrent
using xeto
using xetom
using xetoc
using haystack
using axon
using folio
using hx
using hxm
using hxd
using hxRepo
using testXeto

**
** RepoFuncsTest - tests Axon functions in hx.repo
**
** This test verifies the Axon function layer: correct arg types,
** published options, and documented return types/shapes.
** Core business logic (file placement, env updates, dependency
** resolution) is tested in testXeto::RemoteReposTest.
**
class RepoFuncsTest : RemoteReposTest
{

//////////////////////////////////////////////////////////////////////////
// Setup / Teardown
//////////////////////////////////////////////////////////////////////////

  HxdSys? rt

  override Void teardown()
  {
    Actor.locals.remove(Context.actorLocalsKey)
    rt?.stop
    super.teardown
  }

  ** Boot a test HxdSys using our custom temp ServerEnv, then wire context
  Void initRt()
  {
    boot := HxdBoot.makeTest(tempDir + `rt/`, true)
    boot.xetoEnv = this.env
    rt = boot.init.start
    Actor.locals[Context.actorLocalsKey] = rt.newContext(rt.sys.user.makeUser("test", ["userRole":"su"]))
  }

//////////////////////////////////////////////////////////////////////////
// Repos
//////////////////////////////////////////////////////////////////////////

  Void testRepos()
  {
    initEnv
    initRt

    // libRepos - verify grid shape
    Grid grid := RepoFuncs.libRepos
    verifyGridCols(grid, ["name", "uri", "authToken"])
    verify(grid.size >= 2)
    verify(grid.any { it->name == "xetodev" })

    // libRepoAdd - returns Dict with name, uri
    Dict d := RepoFuncs.libRepoAdd("testrepo", `http://test-1/`)
    verifyEq(d["name"], "testrepo")
    verifyEq(d["uri"],  `http://test-1/`)

    // verify it shows up in libRepos
    grid = RepoFuncs.libRepos
    verify(grid.any { it->name == "testrepo" })

    // libRepoPing - explicit name
    Dict ping := RepoFuncs.libRepoPing("testrepo")
    verifyEq(ping["ping"], "boom!")

    // libRepoLogin - saves token, returns env var name
    Str envName := RepoFuncs.libRepoLogin("testrepo", "my-secret")
    verify(envName.contains("XETO_REPO"))

    // verify token is visible in repos grid
    grid = RepoFuncs.libRepos
    row := grid.find { it->name == "testrepo" }
    verifyNotNull(row)
    verify(row->authToken != null)

    // libRepoLogout - clears token, returns env var name
    envName = RepoFuncs.libRepoLogout("testrepo")
    verify(envName.contains("XETO_REPO"))

    // libRepoRemove - returns "removed"
    Str s := RepoFuncs.libRepoRemove("testrepo")
    verifyEq(s, "removed")

    // verify gone
    grid = RepoFuncs.libRepos
    verifyEq(grid.find { it->name == "testrepo" }, null)

    // libRepoRemove - bad name throws
    verifyErr(UnresolvedErr#) { RepoFuncs.libRepoRemove("badone") }
  }

//////////////////////////////////////////////////////////////////////////
// Search
//////////////////////////////////////////////////////////////////////////

  Void testSearch()
  {
    initEnv
    reg.add("test", `http://test-1/`, Etc.dict0)
    initRt

    // returns Grid with name, version, doc cols
    Grid grid := RepoFuncs.libSearch("test", "alpha")
    verifyGridCols(grid, ["name", "version", "doc"])
    verify(grid.size > 0)
    verify(grid.any { it->name == "alpha" })

    // empty results for unknown lib
    grid = RepoFuncs.libSearch("test", "doesnotexist999")
    verifyGridCols(grid, ["name", "version", "doc"])
    verifyEq(grid.size, 0)
  }

//////////////////////////////////////////////////////////////////////////
// Versions
//////////////////////////////////////////////////////////////////////////

  Void testVersions()
  {
    initEnv
    reg.add("test", `http://test-1/`, Etc.dict0)
    initRt

    // returns Grid with name, version, depends cols
    Grid grid := RepoFuncs.libVersions("test", "alpha", null)
    verifyGridCols(grid, ["name", "version", "depends"])
    verify(grid.size > 0)
    verify(grid.all { it->name == "alpha" })

    // with opts (limit)
    grid = RepoFuncs.libVersions("test", "alpha", Etc.dict1("limit", 2))
    verifyGridCols(grid, ["name", "version", "depends"])
    verifyEq(grid.size, 2)
  }

//////////////////////////////////////////////////////////////////////////
// Fetch
//////////////////////////////////////////////////////////////////////////

  Void testFetch()
  {
    initEnv
    reg.add("test", `http://test-1/`, Etc.dict0)
    initRt

    // fetches lib bytes and writes to file handle
    rt.dir.plus(`io/`).create
    fetchUri := `io/fetch-test.xetolib`
    Dict fd := RepoFuncs.libFetch("test", "alpha", "2.3.0", fetchUri)
    verifyEq(fd["lib"], "alpha")
    verifyEq(fd["version"], "2.3.0")
    verify(fd["size"] is Number)
    verify((fd["size"] as Number).toInt > 0)
    verifyEq(fd["uri"], fetchUri)
    f := rt.dir.plus(`io/fetch-test.xetolib`)
    verifyEq(f.exists, true)
    verify(f.size > 0)
  }

//////////////////////////////////////////////////////////////////////////
// Install
//////////////////////////////////////////////////////////////////////////

  Void testLibInstall()
  {
    initEnv
    remote = reg.add("test", `http://test-1/`, Etc.dict0)
    initRt

    verifyLibNotInstalled("alpha")

    // bad repo name throws
    verifyErr(UnresolvedErr#) { RepoFuncs.libInstall("badrepo", "alpha", null) }

    // single name string, no version constraint
    Grid grid := RepoFuncs.libInstall("test", "alpha", null)
    verifyInstallGrid(grid)
    verifyLibInstalled("alpha", "2.3.0")

    // uninstall to reset
    RepoFuncs.libUninstall("alpha")
    verifyLibNotInstalled("alpha")

    // single name with version constraint ("name-version" format)
    grid = RepoFuncs.libInstall("test", "alpha-1.x.x", null)
    verifyInstallGrid(grid)
    verifyLibInstalled("alpha", "1.2.0")

    // uninstall list
    RepoFuncs.libUninstall(["alpha"])
    verifyLibNotInstalled("alpha")

    // list of names
    grid = RepoFuncs.libInstall("test", ["alpha", "delta"], null)
    verifyInstallGrid(grid)
    verifyLibInstalled("alpha", "2.3.0")
    verifyLibInstalled("delta", "4.0.0")

    // cleanup
    RepoFuncs.libUninstall(["alpha", "delta"])
    verifyLibNotInstalled("alpha")
    verifyLibNotInstalled("delta")

    // {preview} option: does NOT install, returns plan grid
    grid = RepoFuncs.libInstall("test", "alpha", Etc.dict1("preview", Marker.val))
    verifyInstallGrid(grid)
    verifyLibNotInstalled("alpha")

    // transitive deps (beta depends on alpha)
    grid = RepoFuncs.libInstall("test", "beta-1.1.x", null)
    verifyInstallGrid(grid)
    verifyLibInstalled("alpha", "1.1.9")
    verifyLibInstalled("beta",  "1.1.0")

    // cleanup
    RepoFuncs.libUninstall(["alpha", "beta"])
    verifyLibNotInstalled("alpha")
    verifyLibNotInstalled("beta")
  }

//////////////////////////////////////////////////////////////////////////
// Update
//////////////////////////////////////////////////////////////////////////

  Void testUpdate()
  {
    initEnv
    remote = reg.add("test", `http://test-1/`, Etc.dict0)
    initRt

    // install older versions first
    RepoFuncs.libInstall("test", "beta-1.1.x", null)
    verifyLibInstalled("alpha", "1.1.9")
    verifyLibInstalled("beta",  "1.1.0")

    // single name with version constraint
    Grid grid := RepoFuncs.libUpdate("beta-2.x.x", null)
    verifyInstallGrid(grid)
    verifyLibInstalled("beta", "2.0.1")

    // update alpha to latest 2.x.x
    grid = RepoFuncs.libUpdate("alpha-2.x.x", null)
    verifyInstallGrid(grid)
    verifyLibInstalled("alpha", "2.3.0")

    // list of names with constraints
    grid = RepoFuncs.libUpdate(["alpha-2.x.x", "beta-2.x.x"], null)
    verifyInstallGrid(grid)

    // {preview} does NOT update
    RepoFuncs.libUninstall(["alpha", "beta"])
    RepoFuncs.libInstall("test", "beta-1.1.x", null)
    verifyLibInstalled("beta", "1.1.0")
    grid = RepoFuncs.libUpdate("beta-2.x.x", Etc.dict1("preview", Marker.val))
    verifyInstallGrid(grid)
    verifyLibInstalled("beta", "1.1.0") // still at old version

    // cleanup
    RepoFuncs.libUninstall(["alpha", "beta"])
    verifyLibNotInstalled("alpha")
    verifyLibNotInstalled("beta")
  }

//////////////////////////////////////////////////////////////////////////
// Uninstall
//////////////////////////////////////////////////////////////////////////

  Void testUninstall()
  {
    initEnv
    remote = reg.add("test", `http://test-1/`, Etc.dict0)
    initRt

    // install alpha and beta
    RepoFuncs.libInstall("test", "beta-1.1.x", null)
    verifyLibInstalled("alpha", "1.1.9")
    verifyLibInstalled("beta",  "1.1.0")

    // cannot uninstall alpha while beta depends on it
    verifyErr(InstallPlanErr#) { RepoFuncs.libUninstall("alpha") }

    // single name string
    RepoFuncs.libUninstall("beta")
    verifyLibNotInstalled("beta")

    // list of names
    RepoFuncs.libInstall("test", "beta-1.1.x", null)
    Grid grid := RepoFuncs.libUninstall(["alpha", "beta"])
    verifyInstallGrid(grid)
    verifyLibNotInstalled("alpha")
    verifyLibNotInstalled("beta")
  }

//////////////////////////////////////////////////////////////////////////
// Verify Helpers
//////////////////////////////////////////////////////////////////////////

  ** Verify grid has the standard install/update/uninstall columns
  Void verifyInstallGrid(Grid grid)
  {
    verifyGridCols(grid, ["action", "name", "curVer", "newVer", "repo"])
  }

  ** Verify grid column names match expected list
  Void verifyGridCols(Grid grid, Str[] expected)
  {
    verifyEq(grid.cols.map |c->Str| { c.name }, expected)
  }
}
