//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 May 2026  Trevor Adelman  Creation
//

using xeto
using xetom
using haystack
using axon
using hx

**
** Axon functions for xeto remote repo management and installation
**
@Gen
const class RepoFuncs
{

//////////////////////////////////////////////////////////////////////////
// Repo Management
//////////////////////////////////////////////////////////////////////////

  ** Debug dump of the server side XetoEnv including its
  ** resolution mode, search path, and build vars
  @Api @Axon { su = true }
  static Str xetoEnvDebug()
  {
    buf := StrBuf()
    XetoEnv.cur.dump(buf.out)
    return buf.toStr
  }

  ** List configured remote repos as a grid.  The result grid
  ** includes the following columns:
  **   - `name`: programmatic name of the repo
  **   - `uri`: URI endpoint for the repo
  **   - `authToken`: env var name if auth token is configured
  **
  ** Examples:
  **   ```axon
  **   libRepos()
  **   ```
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

  ** Add a new remote repo configuration.  The name must be a valid
  ** tag name and the uri must be a valid URI for the repo endpoint.
  **
  ** Examples:
  **   ```axon
  **   libRepoAdd("myrepo", `https://example.com/xeto`)
  **   ```
  @Api @Axon { su = true }
  static Dict libRepoAdd(Str name, Uri uri)
  {
    r := repos.add(name, uri, Etc.dict0)
    return Etc.dict2("name", r.name, "uri", r.uri)
  }

  ** Remove a remote repo configuration by name.
  **
  ** Examples:
  **   ```axon
  **   libRepoRemove("myrepo")
  **   ```
  @Api @Axon { su = true }
  static Str libRepoRemove(Str name)
  {
    repos.remove(name)
    return "removed"
  }

  ** Ping a remote repo and return metadata.  If repo is null
  ** then the default repo is used.
  **
  ** Examples:
  **   ```axon
  **   libRepoPing(null)
  **   libRepoPing("xetodev")
  **   ```
  @Api @Axon { su = true }
  static Dict libRepoPing(Str? name := null)
  {
    return repo(name).ping
  }

  ** Save an authentication token for a remote repo.  The token
  ** is persisted to fan.props as an environment variable.  If repo
  ** is null then the default repo is used.
  **
  ** Examples:
  **   ```axon
  **   libRepoLogin("xetodev", "my-secret-token")
  **   ```
  @Api @Axon { su = true }
  static Str libRepoLogin(Str? name, Str token)
  {
    n := name ?: repos.def.name
    return repos.saveAuthToken(n, token)
  }

  ** Remove the authentication token for a remote repo.  If repo
  ** is null then the default repo is used.
  **
  ** Examples:
  **   ```axon
  **   libRepoLogout("xetodev")
  **   ```
  @Api @Axon { su = true }
  static Str libRepoLogout(Str? name)
  {
    n := name ?: repos.def.name
    return repos.saveAuthToken(n, null)
  }

//////////////////////////////////////////////////////////////////////////
// Search and Versions
//////////////////////////////////////////////////////////////////////////

  ** Search a remote repo for libs matching the query string.
  ** If repo is null then the default repo is used.
  **
  ** Examples:
  **   ```axon
  **   libSearch(null, "*")
  **   libSearch("xetodev", "ph")
  **   ```
  @Api @Axon { su = true }
  static Grid libSearch(Str? name, Str query)
  {
    r := repo(name)
    res := r.search(RemoteRepoSearchReq(query))
    gb := GridBuilder()
    gb.addCol("name").addCol("version").addCol("doc")
    res.libs.each |lib|
    {
      gb.addRow([lib.name, lib.version, lib.doc])
    }
    return gb.toGrid
  }

  ** List available versions for a lib from a remote repo.
  ** If repo is null then the default repo is used.  Options
  ** include `limit` and `versions` for version constraints.
  **
  ** Examples:
  **   ```axon
  **   libVersions(null, "ph")
  **   libVersions("xetodev", "ph", {limit: 5})
  **   libVersions(null, "ph", {versions: "4.x.x"})
  **   ```
  @Api @Axon { su = true }
  static Grid libVersions(Str? name, Str lib, Dict? opts := null)
  {
    r := repo(name)
    vers := r.versions(lib, opts)
    gb := GridBuilder()
    gb.addCol("name").addCol("version").addCol("depends")
    vers.each |v|
    {
      deps := v.depends(false)
      gb.addRow([v.name, v.version, deps?.join(", ")])
    }
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Install, Update, Uninstall, Fetch
//////////////////////////////////////////////////////////////////////////

  ** Install one or more libs from a remote repo to disk.  The libs
  ** argument accepts a single lib name or a list of lib names.  Use
  ** the format "lib-version" to specify version constraints, for
  ** example "ph-5.0.6" or "ph-5.x.x".  If no version constraint is
  ** specified, the latest available version is used.  If repo is null
  ** then the default repo is used.  Pass `{preview}` in opts to
  ** return the plan without executing.
  **
  ** Examples:
  **   ```axon
  **   libInstall(null, "acme.widgets")
  **   libInstall(null, "acme.widgets-1.x.x")
  **   libInstall(null, ["acme.widgets", "acme.core"])
  **   libInstall(null, "acme.widgets", {preview})
  **   ```
  @Api @Axon { su = true }
  static Grid libInstall(Str? name, Obj libs, Dict? opts := null)
  {
    e := env
    r := repo(name)
    depends := toLibDepends(libs)
    inst := LibInstaller(e, opts ?: Etc.dict0).install(r, depends)
    if (opts?.has("preview") == true) return planToGrid(inst.plan)
    inst.execute
    return planToGrid(inst.plan)
  }

  ** Update one or more installed libs from their origin repo.
  ** The libs argument accepts a single lib name or a list of
  ** lib names.  Use the format "lib-version" to specify version
  ** constraints, for example "ph-5.x.x".  If no version constraint
  ** is specified, the latest available version is used.  Pass
  ** `{preview}` in opts to return the plan without executing.
  **
  ** Examples:
  **   ```axon
  **   libUpdate("ph")
  **   libUpdate("ph-5.x.x")
  **   libUpdate(["ph", "ph.points"])
  **   libUpdate("ph", {preview})
  **   ```
  @Api @Axon { su = true }
  static Grid libUpdate(Obj libs, Dict? opts := null)
  {
    e := env
    depends := toLibDepends(libs)
    inst := LibInstaller(e, opts ?: Etc.dict0).update(depends)
    if (opts?.has("preview") == true) return planToGrid(inst.plan)
    inst.execute
    return planToGrid(inst.plan)
  }

  ** Uninstall one or more libs from disk.  The libs argument
  ** accepts a single lib name or a list of lib names.  Raises
  ** an exception if any of the libs are currently enabled
  ** in the runtime.
  **
  ** Examples:
  **   ```axon
  **   libUninstall("acme.widgets")
  **   libUninstall(["acme.widgets", "acme.core"])
  **   ```
  @Api @Axon { su = true }
  static Grid libUninstall(Obj libs)
  {
    cx := Context.cur
    names := toStrList(libs)

    // check if any libs are enabled in any project
    cx.sys.proj.list.each |p|
    {
      names.each |n|
      {
        if (p.libs.has(n))
          throw Err("Cannot uninstall '$n': lib is enabled in project '$p.name'")
      }
    }

    e := env
    inst := LibInstaller(e).uninstall(names)
    inst.execute
    return planToGrid(inst.plan)
  }

  ** Fetch a xetolib zip for a specific lib and version from a remote
  ** repo and write it to an I/O handle.  If repo is null then the
  ** default repo is used.  The handle follows the same conventions
  ** as `ioWriteStr`.  Returns a Dict with `lib`, `version`, `size`,
  ** and `uri` of the written file.
  **
  ** Examples:
  **   ```axon
  **   libFetch(null, "ph", "4.0.5", `io/ph.xetolib`)
  **   ```
  @Api @Axon { su = true }
  static Dict libFetch(Str? name, Str lib, Str version, Obj handle)
  {
    r := repo(name)
    contents := r.fetch(lib, Version(version))
    Context.cur.rt.exts.io.write(handle) |out| { out.writeBuf(contents) }
    return Etc.dict4("lib", lib, "version", version, "size", Number.makeInt(contents.size), "uri", handle)
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

  private static XetoEnv env(Context cx := Context.cur)
  {
    cx.rt.ns.env
  }

  private static LibDepend[] toLibDepends(Obj names)
  {
    return toStrList(names).map |s->LibDepend|
    {
      dash := s.index("-")
      if (dash == null) return LibDepend(s)
      return LibDepend(s[0..<dash], LibDependVersions(s[dash+1..-1]))
    }
  }

  private static Str[] toStrList(Obj names)
  {
    if (names is Str) return [names]
    if (names is List) return ((List)names).map |v->Str| { v.toStr }
    throw ArgErr("Expected Str or List, not $names.typeof")
  }

  private static Grid planToGrid(LibInstallPlan[] plan)
  {
    gb := GridBuilder()
    gb.addCol("action").addCol("name").addCol("curVer").addCol("newVer").addCol("repo")
    plan.each |p|
    {
      gb.addRow([p.action, p.name, p.curVer?.version, p.newVer?.version, p.repo?.name])
    }
    return gb.toGrid
  }

}
