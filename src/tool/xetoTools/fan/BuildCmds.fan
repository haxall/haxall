//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack

**
** SrcLibCmd is used to work a list of library sources
**
internal abstract class SrcLibCmd : XetoCmd
{
  @Opt { help = "All source libs in working dir" }
  Bool all

  @Opt { help = "All source libs under given directory" }
  File? allIn

  @Arg { help = "List of lib names for any source lib in path" }
  Str[]? libs

  override Str name() { "build" }

  override Str summary() { "Compile xeto source to xetolib" }

  override Int run()
  {
    repo := LibRepo.cur

    // all flag uses all in working dir
    if (all) allIn = Env.cur.workDir

    // allIn diectory
    if (allIn != null)
    {
      vers := LibVersion[,]
      inOsPath := allIn.normalize.osPath
      repo.libs.each |libName|
      {
        ver := repo.latest(libName, false)
        if (ver == null) return ver
        f := ver.file(false)
        if (f != null && ver.isSrc && f.normalize.osPath.startsWith(inOsPath))
          vers.add(ver)
      }

      if (vers.isEmpty)
      {
        printLine("ERROR: no libs found [$allIn.osPath]")
        return 0
      }

      return process(repo, vers)
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
      ver := repo.latest(x, false)
      if (!ver.isSrc) throw Err("Lib src not available: $x")
      return ver
    }
    return process(repo, vers)
  }

  abstract Int process(LibRepo repo, LibVersion[] vers)
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

  override Str summary() { "Compile xeto source to xetolib" }

  override Int process(LibRepo repo, LibVersion[] vers)
  {
    repo.build(vers)
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

  override Int process(LibRepo repo, LibVersion[] vers)
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

**************************************************************************
** Init
**************************************************************************

**
** InitCmd stubs out the source directory for a new xetolib zips
**
internal class InitCmd : XetoCmd
{
  @Opt { help = "Output directory for new lib source dir" }
  File? dir

  @Opt { aliases=["y"]; help = "Skip confirmation" }
  Bool noconfirm

  @Arg { help = "Dotted name of the new lib" }
  Str? libName

  override Str name() { "init" }

  override Str summary() { "Stub out new xeto lib source dir" }

  override Int run()
  {
    if (!nameIsValid(libName)) throw Err("Invalid dotted lib name: $libName")
    rootDir := toRootDir
    libDir  := rootDir + `${libName}/`
    meta    := libDir + `lib.xeto`
    specs   := libDir + `specs.xeto`

    if (meta.exists) throw Err("File already exists: $meta.osPath")
    if (specs.exists) throw Err("File already exists: $specs.osPath")

    echo
    echo("Generate:")
    echo("  dir:        $libDir.osPath")
    echo("  lib.xeto:   $meta.osPath")
    echo("  specs.xeto: $specs.osPath")
    echo

    if (!noconfirm)
    {
      if (!promptConfirm("Generate?")) return 1
    }

    genMeta(meta)
    genSpecs(specs)
    echo("Complete")

    return 0
  }

  private static Bool nameIsValid(Str name)
  {
    name.split('.', false).all |tok| { Etc.isTagName(tok) }
  }

  private File toRootDir()
  {
    if (dir != null) return dir
    return Env.cur.workDir + `src/xeto/`
  }

  private Void genMeta(File file)
  {
    sysVer := env.sysLib.version
    sysDepend := "" + sysVer.major + "." + sysVer.minor + ".x"
    file.out.print(
     """pragma: Lib <
          doc: "TODO"
          version: "0.0.1"
          depends: {
            { lib: "sys", versions: "$sysDepend" }
          }
          org: {
            dis: "TODO"
            uri: "TODO"
          }
        >
         """).close
  }

  private Void genSpecs(File file)
  {
    file.out.print(
     """// My spec documentation
        MySpec : Dict {
        }
        """).close
  }
}

