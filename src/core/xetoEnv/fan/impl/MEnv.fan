//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jul 2025  Brian Frank  Split out implementation
//

using util
using xeto

**
** MEnv is the implementation of XetoEnv
**
const class MEnv : XetoEnv
{

//////////////////////////////////////////////////////////////////////////
// Init
//////////////////////////////////////////////////////////////////////////

  static XetoEnv init()
  {
    //if (cwd == null) cwd = File(`./`).normalize
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

  override const Str mode

}

