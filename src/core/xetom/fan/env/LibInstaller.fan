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
    this.env     = env
    this.opts    = opts
    this.upgrade = opts.has("upgrade")
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
    acc := LibInstallPlan[,]
    libs.each |n|
    {
      cur := env.repo.lib(n)
      p := LibInstallPlan.uninstall(cur)
      acc.add(p)
    }
    return initPlan(acc)
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
      if (install != null && !upgrade) throw InstallPlanErr("Install requires upgrade to '$d.name' (run with -upgrade flag)")
      origin := curVer.origin(false) ?: throw InstallPlanErr("No origin for '$d.name' that requires update")
      newVer = resolveRemoteDepend(origin.repo, d)
      if (newVer == null) throw InstallPlanErr("Unresolved depend '$d' in repo '$install.name'")
      acc.add(name, LibInstallPlan.update(origin.repo, curVer, newVer, origin.transitive))
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

  private RemoteRepo? origin(LibVersion v)
  {
    throw Err("TODO")
  }

//////////////////////////////////////////////////////////////////////////
// Execution
//////////////////////////////////////////////////////////////////////////

  ** Execute the plan
  Void execute()
  {
    echo("TODO execute....")
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
}

