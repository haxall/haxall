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
** Axon functions for remote repository management
**
const class RepoFuncs
{

  **
  ** List configured remote repos as a grid.  The result grid
  ** includes the following columns:
  **   - 'name': programmatic name of the repo
  **   - 'uri': URI endpoint for the repo
  **   - 'authToken': env var name if auth token is configured
  **
  ** Examples:
  **   libRepos()
  **
  @Api @Axon { admin = true }
  static Grid libRepos()
  {
    cx := Context.cur
    repos := cx.rt.ns.env.remoteRepos.list

    gb := GridBuilder()
    gb.addCol("name").addCol("uri").addCol("authToken")
    repos.each |r|
    {
      gb.addRow([r.name, r.uri, r.authTokenEnvName])
    }
    return gb.toGrid
  }

}
