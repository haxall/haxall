//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2023  Brian Frank  Creation
//

using util
using data
using haystack
using xeto

**
** BuildCmd is used to create xetolib zips
**
internal class BuildCmd : XetoCmd
{
  @Arg { help = "Libs to build or \"all\" to rebuild all source libs" }
  Str[]? libs

  override Str name() { "build" }

  override Str summary() { "Compile xeto source to xetolib" }

  override Int run()
  {
    libs := toSrcLibs(this.libs)
    if (libs == null) return 1
    return env.registry.build(libs)
  }
}

**************************************************************************
** Clean
**************************************************************************

**
** CleanCmd deletes xetolib zips if the lib is a source
**
internal class CleanCmd : XetoCmd
{
  @Arg { help = "Libs to clean or \"all\" to clean all source libs" }
  Str[]? libs

  override Str name() { "clean" }

  override Str summary() { "Delete xetolib files for source libs" }

  override Int run()
  {
    libs := toSrcLibs(this.libs)
    if (libs == null) return 1

    libs.each |lib|
    {
      if (!lib.zip.exists) return
      echo("Delete [$lib.zip]")
      lib.zip.delete
    }
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

  @Arg { help = "Qualified name of the new lib" }
  Str? qname

  override Str name() { "init" }

  override Str summary() { "Stub out new xeto lib source dir" }

  override Int run()
  {
    if (!qnameIsValid(qname)) throw Err("Invalid lib qname: $qname")
    rootDir := toRootDir
    libDir  := rootDir + `${qname}/`
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

  private static Bool qnameIsValid(Str qname)
  {
    qname.split('.', false).all |tok| { Etc.isTagName(tok) }
  }

  private File toRootDir()
  {
    if (dir != null) return dir
    cwd := `./`.toFile.normalize
    if (cwd.name == "src") return cwd.plus(`xeto/`)
    if (cwd.plus(`src/`).exists) return cwd.plus(`src/xeto/`)
    return cwd
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

