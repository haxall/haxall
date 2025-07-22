//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Jul 2025  Brian Frank  Garden City Beach
//

using concurrent
using util
using xeto
using xetom

**
** Server side environment with a file system based repo
**
const class ServerEnv : MEnv
{

//////////////////////////////////////////////////////////////////////////
// Init
//////////////////////////////////////////////////////////////////////////

  static XetoEnv initPath()
  {
    // Fantom environment home dir
    homeDir := Env.cur.homeDir

    // first try using xeto.props
    workDir := findWorkDir(`xeto.props`)
    if (workDir != null) return initXetoProps(workDir)

    // next try to using fan.props
    workDir = findWorkDir(`fan.props`)
    if (workDir != null) return initFanProps(workDir)

    // next try to see if we are in a git repo
    workDir = findWorkDir(`.git`)
    if (workDir != null) return make("git", [workDir, homeDir])

    // fallback to just where fantom is installed
    return make("install", [homeDir])
  }

  private static XetoEnv initXetoProps(File workDir)
  {
    path := File[,]
    file := workDir.plus(`xeto.props`)
    try
    {
      props := file.readProps
      path = PathEnv.parsePath(workDir, props["path"] ?: "") |msg, err|
      {
        Console.cur.warn("Parsing $file.osPath: $msg", err)
      }
    }
    catch (Err e)
    {
      Console.cur.warn("Cannot parse props: $file.osPath", e)
      path = [workDir, Env.cur.homeDir]
    }
    return make("xeto.props", path)
  }

  private static XetoEnv initFanProps(File workDir)
  {
    make("fan.props", Env.cur.path)
  }

  private static File? findWorkDir(Uri name)
  {
    File? dir := File(`./`).normalize
    while (dir != null)
    {
      if (dir.plus(name, false).exists) return dir
      dir = dir.parent
    }
    return dir
  }

  ** Constructor
  private new make(Str mode, File[] path)
  {
    this.mode = mode
    this.path = path
  }

//////////////////////////////////////////////////////////////////////////
// XetoEnv
//////////////////////////////////////////////////////////////////////////

  override File homeDir() { path.last }

  override File workDir() { path.first }

  override File installDir() { path.first }

  override const File[] path

  override once Str:Str buildVars()
  {
    acc := Str:Str[:]
    acc.ordered = true
    path.eachr |path|
    {
      f := path + `src/xeto/build.props`
      if (!f.exists) return
      try
      {
        acc.setAll(f.readProps)
      }
      catch (Err e) Console.cur.err("ERROR: cannot parse $f", e)
    }
    return acc.toImmutable
  }

  override once FileRepo repo()
  {
    // lazily create after construction
    FileRepo(this)
  }

//////////////////////////////////////////////////////////////////////////
// Namespace
//////////////////////////////////////////////////////////////////////////

  override LibNamespace createNamespace(LibVersion[] libs)
  {
    repo.createNamespace(libs)
  }

  override LibNamespace createNamespaceFromNames(Str[] names)
  {
    repo.createFromNames(names)
  }

  override LibNamespace createNamespaceFromData(Dict[] recs)
  {
    repo.createFromData(recs)
  }

//////////////////////////////////////////////////////////////////////////
// Build & Compile
//////////////////////////////////////////////////////////////////////////

  ** Run build thru this env (not really thread safe)
  override LibNamespace build(LibVersion[] build)
  {
    // turn verions to lib depends
    buildAsDepends := build.map |v->LibDepend|
    {
      if (!v.isSrc) throw ArgErr("Not source lib: $v")
      return MLibDepend(v.name, LibDependVersions(v.version))
    }

    // solve dependency graph for full list of libs
    libs := repo.solveDepends(buildAsDepends)

    // build map of lib name to
    buildFiles := Str:File[:]
    build.each |v| { buildFiles[v.name] = XetoUtil.srcToLibZip(v) }

    // create namespace and force all libs to be compiled
    libCacheClear
    ns := LocalNamespace(LocalNamespaceInit(this, repo, libs, buildFiles))
    ns.libs

    // report which libs could not be compiled
    ns.versions.each |v|
    {
      if (ns.libStatus(v.name).isErr) echo("ERROR: could not compile $v.name.toCode")
    }

    return ns
  }

  override XetoLib compile(LibNamespace ns, LibVersion v)
  {
    c := XetoCompiler
    {
      it.ns      = ns
      it.libName = v.name
      it.input   = v.file
      it.build   = ((LocalNamespace)ns).build?.get(v.name)
    }
    return c.compileLib
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  override const Str mode

  override Str:Str debugProps()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["xeto.version"] = typeof.pod.version.toStr
    acc["xeto.mode"] = mode
    acc["xeto.workDir"] = workDir.osPath
    acc["xeto.homeDir"] = homeDir.osPath
    acc["xeto.installDir"] = installDir.osPath
    acc["xeto.path"] = path.map |f->Str| { f.osPath }
    acc["xeto.buildVars"] = buildVars
    return acc
  }

  override Void dump(OutStream out := Env.cur.out)
  {
    AbstractMain.printProps(debugProps, ["out":out])
  }
}

