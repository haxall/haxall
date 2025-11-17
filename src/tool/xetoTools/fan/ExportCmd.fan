//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Aug 2024  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

internal abstract class ExportCmd : XetoCmd
{
  @Opt { help = "All libs installed in repo" }
  Bool all

  @Opt { help = "Dump debug info as processing" }
  Bool verbose

  @Opt { help = "Output directory (generates one file per target)" }
  File? outDir

  @Opt { help = "Output file (combine all targets in one file, default to stdout)" }
  File? outFile

  @Arg { help = "Libs, specs, and instances to export" }
  Str[]? targets

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Targets:")
    out.printLine("  ph.points                   // latest version of lib")
    out.printLine("  ph.points-1.0.43            // specific version of lib")
    out.printLine("  ph.points::RunCmd           // latest version of spec")
    out.printLine("  ph.points-1.0.43::RunCmd    // specific version of spec")
    out.printLine("  ion.actions::save           // instance in a lib")
    out.printLine("Examples:")
    out.printLine("  xeto $name sys                   // latest version of lib")
    out.printLine("  xeto $name sys-1.0.3             // specific lib version")
    out.printLine("  xeto $name sys ph ph.points      // multiple libs")
    out.printLine("  xeto $name ph::Rtu               // one spec")
    out.printLine("  xeto $name ph -outFile foo.xeto  // output to file")
    out.printLine("  xeto $name sys ph -outDir myDir  // output each target to file in dir")
    out.printLine("  xeto $name -all -outDir myDir    // output every lib to file in dir")
    return 1
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    // sanity checks
    if (!checkArgs) return 1

    // find targets
    env := XetoEnv.cur
    targets := findTargets(env.repo)
    if (verbose)
    {
      printLine("\nFind Targets:")
      targets.each |x| { printLine("  $x") }
    }

    // create namespace for targets
    ns := createNamespace(env, targets)
    if (verbose)
    {
      printLine("\nCreate Namespace:")
      ns.versions.each |x| { printLine("  $x") }
    }

    // export
    exportTargets(ns, targets)

    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Check Args
//////////////////////////////////////////////////////////////////////////

  private Bool checkArgs()
  {
    if (outDir != null && outFile != null)
    {
      err("Cannot specify both outDir and outFile")
      return false
    }

    if (targets == null && !all)
    {
      err("No targets specified")
      return false
    }

    return true
  }

//////////////////////////////////////////////////////////////////////////
// Find Targets
//////////////////////////////////////////////////////////////////////////

  private ExportTarget[] findTargets(LibRepo repo)
  {
    if (all) return findAllTargets(repo)
    if (targets == null) return ExportTarget[,]
    return targets.map |name->ExportTarget| { findTarget(repo, name) }
  }

  private ExportTarget[] findAllTargets(LibRepo repo)
  {
    repo.libs.map |libName->ExportTarget| { findTarget(repo, libName) }
  }

  private ExportTarget findTarget(LibRepo repo, Str name)
  {
    libName := name
    version := null
    specName := null

    // parse out spec/instance name
    if (name.contains("::"))
    {
      libName = XetoUtil.qnameToLib(name)
      specName = XetoUtil.qnameToName(name)
    }

    // parse out version
    if (libName.contains("-"))
    {
      dash := libName.index("-")
      version = Version.fromStr(libName[dash+1..-1])
      libName = libName[0..<dash]
    }

    // resolve library version
    lib := version == null ?
           repo.latest(libName) :
           repo.version(libName, version)

    return ExportTarget(lib, specName)
  }

//////////////////////////////////////////////////////////////////////////
// Namespace
//////////////////////////////////////////////////////////////////////////

  private Namespace createNamespace(XetoEnv env, ExportTarget[] targets)
  {
    // map targets to a list of dependencies
    depends := Str:LibDepend[:]
    targets.each |t|
    {
      depends[t.lib.name] = t.depend
    }

    // solve dependencies
    versions := env.repo.solveDepends(depends.vals)

    // create namespace from our dependency solution
    return env.createNamespace(versions)
  }

//////////////////////////////////////////////////////////////////////////
// Export
//////////////////////////////////////////////////////////////////////////

  private Void exportTargets(Namespace ns, ExportTarget[] targets)
  {
    if (outDir != null)
      exportToDir(ns, targets)
    else
      exportToFile(ns, targets)
  }

  private Void exportToDir(Namespace ns, ExportTarget[] targets)
  {
    targets.each |t|
    {
      name := toFileName(t).replace("::", "_")
      file := outDir.uri.plusSlash.plusName(name).toFile
      withOut(file) |out|
      {
        ex := initExporter(ns, out)
        ex.start
        exportTarget(ns, ex, t)
        ex.end
      }
    }
  }

  private Void exportToFile(Namespace ns, ExportTarget[] targets)
  {
    withOut(outFile) |out|
    {
      ex := initExporter(ns, out)
      ex.start
      targets.each |t| { exportTarget(ns, ex, t) }
      ex.end
    }
  }

  private Void exportTarget(Namespace ns, Exporter ex, ExportTarget t)
  {
    lib := ns.lib(t.lib.name)
    if (t.specName == null)
    {
      ex.lib(lib)
      return
    }

    spec := lib.spec(t.specName, false)
    if (spec != null)
    {
      ex.spec(spec)
      return
    }

    instance := lib.instance(t.specName, false)
    if (instance != null)
    {
      ex.instance(instance)
      return
    }

    throw Err("Unknown spec/instance $lib.name::$t.specName")
  }

  abstract Exporter initExporter(Namespace ns, OutStream out)

  abstract Str toFileName(ExportTarget t)
}

**************************************************************************
** ExportTarget
**************************************************************************

internal const class ExportTarget
{
  new make(LibVersion lib, Str? specName)
  {
    this.lib = lib
    this.specName = specName
    this.depend = LibDepend(lib.name, LibDependVersions(lib.version))
  }
  const LibVersion lib
  const Str? specName
  const LibDepend depend

  override Str toStr() { specName == null ? lib.toStr : "$lib::$specName" }
}

