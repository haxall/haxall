//
// Copyright (c) 2027, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Apr 2026  Brian Frank  Creation
//

using util
using concurrent
using xeto
using haystack

**
** LibInstaller handles planning and executing install/update/uninstall
**
class LibInstaller
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(XetoEnv env, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    this.env        = env
    this.opts       = opts
    this.upgrade    = opts.has("upgrade")
    this.installDir = opts["installDir"] ?: env.installDir
  }

//////////////////////////////////////////////////////////////////////////
// State
//////////////////////////////////////////////////////////////////////////

  ** Environment
  const XetoEnv env

  ** Options
  const Dict opts

  ** Option that allows install to update currently installed libs
  ** if required to meet dependencies (default is false)
  const Bool upgrade

  ** Path directory as root of lib/xeto to install to
  const File installDir

  ** Get the plan or raise exception if not planned
  LibInstallPlan[] plan() { planRef ?: throw Err("Not planned!") }

  ** Dump plan to table
  Void planDump(Console con := Console.cur)
  {
    table := Obj[,]

    header := ["action", "name", "cur", "new"]
    hasRepo := plan.any { it.repo != null }
    hasTran := plan.any { it.transitive }
    if (hasRepo) header.add("repo")
    if (hasTran) header.add("transitive")
    table.add(header)

    plan.each |p|
    {
      row := Obj?[p.action, p.name, p.curVer?.version, p.newVer?.version]
      if (hasRepo) row.add(p.repo?.name)
      if (hasTran) row.add(Marker.fromBool(p.transitive))
      table.add(row)
    }

    con.table(table)
  }

//////////////////////////////////////////////////////////////////////////
// Planning
//////////////////////////////////////////////////////////////////////////

  ** Plan an install operation from given repo
  This install(RemoteRepo repo, LibDepend[] libs)
  {
    // sanity check none are already installed
    libs.each |lib|
    {
      cur := env.repo.lib(lib.name, false)
      if (cur != null) throw InstallPlanErr("Lib '$lib.name' already installed (run update)")
    }
    initPlan(resolvePlan(repo, libs))
    return this
  }

  ** Plan an update operation using origin repo of each lib
  This update(LibDepend[] libs)
  {
    initPlan(resolvePlan(null, libs))
    return this
  }

  ** Plan an uninstall operation
  This uninstall(Str[] libs)
  {
    // build plan, lookup each lib as first step
    acc := Str:LibInstallPlan[:]
    libs.each |n|
    {
      cur := env.repo.lib(n)
      if (cur.isSrc) throw InstallPlanErr("Cannot delete source lib '$n'")
      p := LibInstallPlan.uninstall(cur)
      acc.add(n, p)
    }

    // now verify we aren't breaking any install depends
    env.repo.libs.each |lib|
    {
      // skip it if its in our delete list
      if (acc[lib.name] != null) return

      // check
      lib.depends.each |d|
      {
        toDelete := acc[d.name]
        if (toDelete != null)
          throw InstallPlanErr("Cannot uninstall '$toDelete.name', required by '$lib.name'")
      }
    }

    return initPlan(acc.vals)
  }

  ** Set plan and return this
  private This initPlan(LibInstallPlan[] plan)
  {
    if (planRef != null) throw Err("Already planned!")
    planRef = plan
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Resolve
//////////////////////////////////////////////////////////////////////////

  ** Resolve a lib dependency against given repo
  private LibInstallPlan[] resolvePlan(RemoteRepo? repo, LibDepend[] libs)
  {
    // recursively solve dependencies
    acc := Str:LibInstallPlan[:]
    libs.each |lib|
    {
      resolveDepend(acc, repo, lib, false)
    }

    // normalize plan
    list := acc.vals
    // list = list.findAll |p| { p.action != LibInstallAction.none }
    list.sort |a, b| { a.name <=> b.name }
    return list
  }

  ** Recursively solve dependencies
  private Void resolveDepend(Str:LibInstallPlan acc, RemoteRepo? install, LibDepend d, Bool transitive)
  {
    // skip if already processed
    name := d.name
    if (acc[name] != null) return

    // check if we have a current version
    LibVersion? curVer := env.repo.lib(name, false)
    LibVersion? newVer := null

    // if not installed, then this is an install action
    if (curVer == null)
    {
      if (install == null) throw InstallPlanErr("Install from undefined remote repo")
      newVer = resolveRemoteDepend(install, d)
      acc.add(name, LibInstallPlan.install(install, newVer, transitive))
    }

    // check if we need an update an installed version
    else if (!d.versions.contains(curVer.version))
    {
      origin := toUpdateRepo(install, curVer)
      newVer = resolveRemoteDepend(origin, d)
      if (newVer == null) throw InstallPlanErr("Unresolved depend '$d' in repo '$install.name'")
      acc.add(name, LibInstallPlan.update(origin, curVer, newVer, transitive))
    }

    // now ensure depends are solved
    xVer := newVer ?: curVer
    xVer.depends.each |x|
    {
      resolveDepend(acc, install, x, true)
    }
  }

  private LibVersion? resolveRemoteDepend(RemoteRepo? repo, LibDepend d)
  {
    ver := repo.latestMatch(d, false)
    if (ver == null) throw InstallPlanErr("Unresolved dependency '$d' in repo '$repo.name'")
    return ver
  }

  private RemoteRepo? toUpdateRepo(RemoteRepo? install, LibVersion v)
  {
    // cannot update from install without explicit -u flag
    if (install != null && !upgrade)
      throw InstallPlanErr("Install requires upgrade to '$v.name' (run with -upgrade flag)")

    // get origin
    o := v.origin(false)
    if (o == null)
      throw InstallPlanErr("No origin for '$v.name' that requires update")

    // assume uri is auth first
    repo := env.remoteRepos.getByUri(o.uri, false)
    if (repo != null) return repo

    // fallback to name
    repo = env.remoteRepos.get(o.repoName, false)
    if (repo != null) return repo

    // give up
    throw InstallPlanErr("Origin for lib '$v.name' is not configured: $o.repoName $o.uri")
  }

//////////////////////////////////////////////////////////////////////////
// Execution
//////////////////////////////////////////////////////////////////////////

  ** Execute the plan
  Void execute()
  {
    // first pass fetches everything we need to temp directory
    ts := DateTime.now.toLocale("YYMMDD-hhmmss")
    tempDir := Env.cur.tempDir + `xeto-install-$ts/`
    fetched := File[,]
    plan.each |p|
    {
      if (p.action.isFetch)
        fetched.addAll(fetch(p, tempDir))
    }

    // now move fetched files to the install workDir
    workDirLib := installDir + `lib/xeto/`
    moveOpts := ["overwrite":true]
    fetched.each |f| { f.copyInto(workDirLib, moveOpts) }
    tempDir.delete

    // finally delete any uninstalls
    plan.each |p|
    {
      if (p.action === LibInstallAction.uninstall)
        libDelete(p)
    }

    // force reload of env
    env.repo.rescan
  }

  ** Fetch plan lib
  private File[] fetch(LibInstallPlan p, File tempDir)
  {
    try
    {
      libFile := tempDir.plus(`${p.name}.xetolib`)
      originFile := tempDir.plus(`${p.name}-origin.props`)

      // fetch from remote repo
      contents := p.repo.fetch(p.name, p.newVer.version)
      libFile.out.writeBuf(contents).close

      // write origin file
      originFile.out.writeProps(p.toOriginProps(contents)).close

      return [libFile, originFile]
    }
    catch (Err e)
    {
      throw InstallExecuteErr("Fetch failed for lib '$p.name' from '$p.repo.name'", e)
    }
  }

  private Void libDelete(LibInstallPlan p)
  {
    f := p.curVer.file
    o := f.parent + `${p.name}-origin.props`
    f.delete
    o.delete
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private LibInstallPlan[]? planRef
}

**************************************************************************
** LibInstallPlan
**************************************************************************

**
** LibInstallPlan describes a single lib change within a `LibInstaller`.
**
const class LibInstallPlan
{
  ** Install constructor
  internal new install(RemoteRepo repo, RemoteLibVersion newVer, Bool transitive)
  {
    this.action     = LibInstallAction.install
    this.name       = newVer.name
    this.curVer     = null
    this.newVer     = newVer
    this.repo       = repo
    this.transitive = transitive
  }

  ** Update constructor
  internal new update(RemoteRepo repo, LibVersion curVer, RemoteLibVersion newVer, Bool transitive)
  {
    this.action     = LibInstallAction.update
    this.name       = curVer.name
    this.curVer     = curVer
    this.newVer     = newVer
    this.repo       = repo
    this.transitive = transitive
  }

  ** Uninstall constructor
  internal new uninstall(LibVersion curVer)
  {
    this.action     = LibInstallAction.uninstall
    this.name       = curVer.name
    this.curVer     = curVer
    this.newVer     = null
    this.repo       = null
    this.transitive = false
  }

   ** None constructor
  internal new none(LibVersion curVer)
  {
    this.action     = LibInstallAction.none
    this.name       = curVer.name
    this.curVer     = curVer
    this.newVer     = null
    this.repo       = null
    this.transitive = false
  }

  ** Constructor
  internal new make(|This| f) { f(this) }

  ** Action for this library
  const LibInstallAction action

  ** Lib name
  const Str name

  ** Current version or null if install
  const LibVersion? curVer

  ** Target version for plan or null if uninstall
  const LibVersion? newVer

  ** Remote repo the lib will be fetched from for install
  const RemoteRepo? repo

  ** True if this action is via a transitive dependency.
  const Bool transitive

  ** Debug string
  override Str toStr() { "$action $curVer -> $newVer" }

  ** Origin props file
  Str:Str toOriginProps(Buf contents)
  {
    if (repo == null) throw Err("Not origin action $this")
    return Str:Str[
      "repo":    repo.name,
      "uri":     repo.uri.toStr,
      "fetched": DateTime.now.toStr,
      "digest":  "sha256:" + contents.toDigest("SHA-256").toBase64Uri,
    ]
  }
}

**************************************************************************
** LibInstallAction
**************************************************************************

@Js
enum class LibInstallAction
{
  install,
  update,
  uninstall,
  none

  Bool isFetch() { this === install || this === update }
}

