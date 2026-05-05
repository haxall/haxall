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
const class RepoFuncs
{

//////////////////////////////////////////////////////////////////////////
// Repo Management
//////////////////////////////////////////////////////////////////////////

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
// Search and Versions
//////////////////////////////////////////////////////////////////////////

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
