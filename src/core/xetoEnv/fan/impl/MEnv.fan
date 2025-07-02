//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jul 2025  Brian Frank  Split out implementation
//

using util
using xeto
using haystack

**
** MEnv is the base for XetoEnv implementations.  We
** have a ServerEnv and ClientEnv.
**
@Js
abstract const class MEnv : XetoEnv
{
  static XetoEnv init()
  {
    if (Env.cur.runtime == "js")
      return BrowserEnv()
    else
      return Slot.findMethod("xetoEnv::ServerEnv.initPath").call
  }

  override Str dictDis(Dict x, Str? def)
  {
    Etc.dictToDis(x, def)
  }

  override Dict dictMap(Dict x, |Obj val, Str name->Obj| f)
  {
    acc := Str:Obj[:]
    x.each |v, n| { acc[n] = f(v, n) }
    return Etc.dictFromMap(acc)
  }
}

**************************************************************************
** JsEnv
**************************************************************************

**
** Browser client based environment
**
@Js
const class BrowserEnv : MEnv
{
  override LibRepo repo() { throw unavailErr() }

  override File homeDir() { throw unavailErr() }

  override File workDir() { throw unavailErr() }

  override File installDir() { throw unavailErr() }

  override File[] path() { throw unavailErr() }

  override Str mode() { "browser" }

  override Str:Str debugProps() { Str:Obj[:] }

  override Void dump(OutStream out := Env.cur.out) {}

  static Err unavailErr() { Err("Not available in browser") }
}

**************************************************************************
** ServerEnv
**************************************************************************

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
    this.repo = Type.find("xetoc::FileRepo").make([this])
  }

//////////////////////////////////////////////////////////////////////////
// XetoEnv
//////////////////////////////////////////////////////////////////////////

  override const LibRepo repo

  override File homeDir() { path.last }

  override File workDir() { path.first }

  override File installDir() { path.first }

  override const File[] path

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
    return acc
  }

  override Void dump(OutStream out := Env.cur.out)
  {
    AbstractMain.printProps(debugProps, ["out":out])
  }
}

