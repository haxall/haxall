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
  new make(XetoEnv env) { this.env = env }

//////////////////////////////////////////////////////////////////////////
// State
//////////////////////////////////////////////////////////////////////////

  ** Environment
  const XetoEnv env

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
    acc := LibInstallPlan[,]
    libs.each |lib|
    {
      n := lib.name
      cur := env.repo.latest(n, false)
      if (cur != null) throw Err("Lib already installed: $n")

      p := LibInstallPlan
      {
        it.action = LibInstallAction.install
        it.name   = n
        it.newVer = RemoteLibVersion(n, Version("0.0.0")) // TODO
        it.repo   = repo
      }
      acc.add(p)
    }
    return initPlan(acc)
  }

  ** Plan an update operation using origin repo of each lib
  This update(LibDepend[] libs)
  {
    acc := LibInstallPlan[,]
    libs.each |lib|
    {
      n := lib.name
      cur := env.repo.latest(n)

      p := LibInstallPlan
      {
        it.action = LibInstallAction.update
        it.name   = n
        it.curVer = cur
        it.newVer = RemoteLibVersion(n, Version("0.0.0")) // TODO
      }
      acc.add(p)
    }
    return initPlan(acc)
  }

  ** Plan an uninstall operation
  This uninstall(Str[] libs)
  {
    acc := LibInstallPlan[,]
    libs.each |n|
    {
      cur := env.repo.latest(n)
      p := LibInstallPlan
      {
        it.action = LibInstallAction.uninstall
        it.name   = n
        it.curVer = cur
        it.newVer = null
      }
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

