//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** SrcLibCmd is used to work a list of library sources
**
abstract class SrcLibCmd : XetoCmd
{
  @Opt { help = "All source libs in repo" }
  Bool all

  @Opt { help = "All source libs under working directory (default)" }
  Bool allWork

  @Opt { help = "All source libs under given directory" }
  File? allIn

  @Arg { help = "List of lib names for any source lib in path" }
  Str[]? libs

  override Str name() { "build" }

  override Str summary() { "Compile xeto source to xetolib" }

  override Int run()
  {
    env := XetoEnv.cur

    // no flags defaults to allWork
    if (libs == null && allIn == null)
      allWork = true

    if (allWork) allIn = Env.cur.workDir

    // all or allIn diectory
    if (all || allIn != null)
    {
      vers := LibVersion[,]
      inOsPath := allIn?.normalize?.pathStr
      env.repo.libs.each |libName|
      {
        ver := env.repo.latest(libName, false)
        if (ver == null) return null

        f := ver.file(false)
        if (f == null) return
        if (!ver.isSrc) return

        if (all || f.normalize.pathStr.startsWith(inOsPath))
          vers.add(ver)
      }

      if (vers.isEmpty)
      {
        printLine("ERROR: no libs found [$allIn.osPath]")
        return 0
      }

      return process(env, vers)
    }

    // sanity check that libNames specified
    if (libs  == null || libs.isEmpty)
    {
      printLine("ERROR: no libs specified")
      return 1
    }

    // explicit list of lib names
    vers := libs.map |x->LibVersion|
    {
      ver := env.repo.latest(x, false)
      if (ver == null || !ver.isSrc) throw Err("Lib src not available: $x")
      return ver
    }
    return process(env, vers)
  }

  abstract Int process(XetoEnv env, LibVersion[] vers)
}

**************************************************************************
** BuildCmd
**************************************************************************

**
** BuildCmd is used to create xetolib zips
**
internal class BuildCmd : SrcLibCmd
{
  override Str name() { "build" }

  override Str[] aliases() { ["b"] }

  override Str summary() { "Compile xeto source to xetolib" }

  override Int process(XetoEnv env, LibVersion[] vers)
  {
    ((MEnv)env).build(vers)
    return 0
  }
}

**************************************************************************
** Clean
**************************************************************************

**
** CleanCmd deletes xetolib zips if the lib is a source
**
internal class CleanCmd : SrcLibCmd
{
  override Str name() { "clean" }

  override Str summary() { "Delete all xetolib versions for source libs" }

  override Int process(XetoEnv env, LibVersion[] vers)
  {
    vers.each |ver|
    {
      clean(ver)
    }
    return 0
  }

  private Void clean(LibVersion v)
  {
    // directory for all xetolibs
    libDir := XetoUtil.srcToLibDir(v)
    printLine("Delete [$libDir.osPath]")
    libDir.delete
    return 0
  }
}

