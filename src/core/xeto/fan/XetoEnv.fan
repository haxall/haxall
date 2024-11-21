//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Nov 2024  Brian Frank  Creation
//

using concurrent
using util

**
** XetoEnv models the server side file system search path.
**
const class XetoEnv
{

//////////////////////////////////////////////////////////////////////////
// Factory
//////////////////////////////////////////////////////////////////////////

  ** Current environment for the VM
  static XetoEnv cur()
  {
    cur := curRef.val as XetoEnv
    if (cur != null) return cur
    curRef.compareAndSet(null, init(null))
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

  ** Constructor
  @NoDoc new make(Str mode, File[] path)
  {
    this.mode = mode
    this.pathRef = path
  }

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  ** Home directory where xeto software is installed
  virtual File homeDir() { path.last }

  ** Working directory - first directory in the path.  The workDir
  ** is used as default location for 'xeto init' to create new libs.
  virtual File workDir() { path.first }

  ** Default install directory for 'xeto install'.
  ** Default is the `workDir`
  virtual File installDir() { path.first }

  ** List of paths to search for libraries in both lib and src format
  File[] path() { pathRef }
  private const File[] pathRef

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Mode used to determine path
  @NoDoc const Str mode

  ** Debug props
  @NoDoc Str:Str debugProps()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["xeto.version"] = typeof.pod.version.toStr
    acc["xeto.mode"] = mode
    acc["xeto.workDir"] = workDir.osPath
    acc["xeto.homeDir"] = homeDir.osPath
    acc["xeto.installDir"] = installDir.osPath
    acc["xeto.path"] = path.map |f->Str| { f.osPath }
    return acc
  }

  ** Debug dump
  @NoDoc Void dump(OutStream out := Env.cur.out)
  {
    AbstractMain.printProps(debugProps, ["out":out])
  }

  ** Main to debug dump
  @NoDoc static Void main() { echo; cur.dump; echo }

//////////////////////////////////////////////////////////////////////////
// Init
//////////////////////////////////////////////////////////////////////////

  ** Init env with optional currrent working directory
  @NoDoc static XetoEnv init(File? cwd)
  {
    if (cwd == null) cwd = File(`./`).normalize
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
    XetoEnv("fan.props", Env.cur.path)
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
}

