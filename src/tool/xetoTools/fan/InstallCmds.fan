//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Apr 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetom
using xetodoc

** Base class for install, update, uninstall
internal abstract class AbstractInstallCmd : RemoteCmd
{
  @Opt { help = "Dry run preview only" }
  Bool preview

  @Opt { help = "Skip confirmation"; aliases=["y"] }
  Bool yes

  RemoteRepo remote(Str? repoName)
  {
    if (repoName == null)
      return registry.def
    else
      return registry.get(repoName)
  }

  Int previewAndExecute(LibInstaller installer)
  {
    // preview plan
    what := cmdName.capitalize
    printLine
    printLine("$what plan:")
    printLine
    installer.planDump
    if (preview) return 0

    // confirm
    if (!yes)
    {
      printLine
      if (!promptConfirm("$what?"))
      {
        err("Cancelled")
        return 1
      }
      printLine
    }

    // execute
    installer.execute
    return ok("$what success [$installer.plan.size libs]")
  }
}

**************************************************************************
** InstallCmd
**************************************************************************

internal class InstallCmd : AbstractInstallCmd
{
  override Str cmdName() { "install" }

  override Str[] aliases() { ["i"] }

  override Str summary() { "Install one or more libs from remote repo" }

  @Opt { help = "Name of remote repo (if not default)"; aliases = ["r"] }
  Str? repo

  @Opt { help = "Upgrade currently installed libs if needed"; aliases=["u"] }
  Bool upgrade

  @Arg { help = "Libs to install formatted as name or name-x.x.x" }
  Str[]? libs

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto install foo     // install latest version of 'foo' from default remote repo")
    out.printLine("  xeto i foo           // using command alias")
    out.printLine("  xeto i foo-3.0.7     // install specific version")
    out.printLine("  xeto i foo-3.0.x     // install with depend wildcards")
    out.printLine("  xeto i foo bar baz   // install multiple libs")
    out.printLine("  xeto i foo -r acme   // install from remote repo named 'acme'")
    out.printLine("  xeto i foo -preview  // dry run preview only")
    out.printLine("  xeto i foo -y        // skip confirmation")
    out.printLine("  xeto i foo -upgrade  // update installed libs if needed to meet foo depends")
    return 1
  }

  override Int run()
  {
    try
    {
      opts := Etc.dict1x("upgrade", Marker.fromBool(upgrade))
      repo := remote(repo)
      libs := this.libs.map |x->LibDepend| { LibDependArg(x).depend }
      inst := LibInstaller(env, opts).install(repo, libs)
      return previewAndExecute(inst)
    }
    catch (Err e)
    {
      return err("Install failed", e)
    }
  }
}

**************************************************************************
** UpdateCmd
**************************************************************************

internal class UpdateCmd : AbstractInstallCmd
{
  override Str cmdName() { "update" }

  override Str[] aliases() { ["u"] }

  override Str summary() { "Update libs from their origin remote repo" }

  @Arg { help = "Libs to update formatted as name or name-x.x.x" }
  Str[]? libs

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto update foo      // update to latest version of 'foo'")
    out.printLine("  xeto u foo           // using command alias")
    out.printLine("  xeto u foo -preview  // dry run preview only")
    out.printLine("  xeto u foo -y        // skip confirmation")
    return 1
  }

  override Int run()
  {
    try
    {
      libs := this.libs.map |x->LibDepend| { LibDependArg(x).depend }
      inst := LibInstaller(env).update(libs)
      return previewAndExecute(inst)
    }
    catch (Err e)
    {
      return err("Update failed", e)
    }
  }
}

**************************************************************************
** UninstallCmd
**************************************************************************

internal class UninstallCmd : AbstractInstallCmd
{
  override Str cmdName() { "uninstall" }

  override Str summary() { "Uninstall one or more libs from local repo" }

  @Arg { help = "Lib names to remove" }
  Str[]? libs

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto uninstall foo           // remove 'foo' from local repo")
    out.printLine("  xeto uninstall foo bar baz   // remove multiple libs from local repo")
    out.printLine("  xeto uninstall foo -preview  // dry run preview only")
    out.printLine("  xeto uninstall foo -y        // skip confirmation")
    return 1
  }

  override Int run()
  {
    try
    {
      inst := LibInstaller(env).uninstall(libs)
      return previewAndExecute(inst)
    }
    catch (Err e)
    {
      return err("Update failed", e)
    }
  }
}

