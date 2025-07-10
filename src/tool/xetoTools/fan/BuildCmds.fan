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
using xetom
using xetoDoc

**************************************************************************
** DocCmd
**************************************************************************

**
** DocCmd compiles a namespace to docs
**
internal class DocCmd : SrcLibCmd
{
  override Str name() { "doc" }

  override Str summary() { "Compile libs to JSON doc AST files" }

  @Opt { help = "Output directory" }
  File? outDir

  override Int process(LibRepo repo, LibVersion[] vers)
  {
    // flatten and build namespace
    depends := vers.map |x->LibDepend| { x.asDepend }
    flatten := repo.solveDepends(depends)
    ns := repo.createNamespace(flatten)

    // get libs to compile
    libs := vers.map |v->Lib| { ns.lib(v.name) }

    // output directory
    outDir := this.outDir ?: Env.cur.workDir + `doc-xeto/`

    // compile
    c := DocCompiler
    {
      it.ns     = ns
      it.libs   = libs
      it.outDir = outDir
    }
    c.compile
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
    err := XetoUtil.libNameErr(libName)
    if (err != null) throw Err("Invalid lib name $libName.toCode: $err")
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

  private File toRootDir()
  {
    if (dir != null) return dir
    return Env.cur.workDir + `src/xeto/`
  }

  private Void genMeta(File file)
  {
    sysVer := LibNamespace.system.sysLib.version
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

