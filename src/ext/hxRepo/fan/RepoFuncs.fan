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
** Axon functions for xeto remote repo management and installation
**
const class RepoFuncs
{

  @Api @Axon { su = true }
  static Grid libRepos()
  {
    gb := GridBuilder()
    gb.addCol("name").addCol("uri").addCol("authToken")
    repos.list.each |r|
    {
      gb.addRow([r.name, r.uri, r.authTokenEnvName])
    }
    return gb.toGrid
  }

  @Api @Axon { su = true }
  static Dict libRepoAdd(Str name, Uri uri)
  {
    r := repos.add(name, uri, Etc.dict0)
    return Etc.dict2("name", r.name, "uri", r.uri)
  }

  @Api @Axon { su = true }
  static Str libRepoRemove(Str name)
  {
    repos.remove(name)
    return "removed"
  }

  @Api @Axon { su = true }
  static Dict libRepoPing(Str? name := null)
  {
    return repo(name).ping
  }

  @Api @Axon { su = true }
  static Str libRepoLogin(Str? name, Str token)
  {
    n := name ?: repos.def.name
    return repos.saveAuthToken(n, token)
  }

  @Api @Axon { su = true }
  static Str libRepoLogout(Str? name)
  {
    n := name ?: repos.def.name
    return repos.saveAuthToken(n, null)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private static RemoteRepoRegistry repos(Context cx := Context.cur)
  {
    cx.rt.ns.env.remoteRepos
  }

  private static RemoteRepo repo(Str? name, Context cx := Context.cur)
  {
    name == null ? repos(cx).def : repos(cx).get(name)
  }

}
