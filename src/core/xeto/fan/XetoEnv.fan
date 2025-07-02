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
@Js
abstract const class XetoEnv
{

//////////////////////////////////////////////////////////////////////////
// Factory
//////////////////////////////////////////////////////////////////////////

  ** Current environment for the VM
  static XetoEnv cur() { curRef }
  private const static XetoEnv? curRef
  static
  {
    try
      curRef = Slot.findMethod("xetoEnv::MEnv.init").call
    catch (Err e)
      Console.cur.err("Cannot init XetoEnv", e)
  }

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  ** Repository of all installed xeto libs. This is only available
  ** on server environments, will raise exception in a browser.
  abstract LibRepo repo()

  ** Home directory where xeto software is installed
  abstract File homeDir()

  ** Working directory - first directory in the path.  The workDir
  ** is used as default location for 'xeto init' to create new libs.
  abstract File workDir()

  ** Default install directory for 'xeto install'.
  ** Default is the `workDir`
  abstract File installDir()

  ** List of paths to search for libraries in both lib and src format
  abstract File[] path()

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Mode used to determine path
  @NoDoc abstract Str mode()

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

}

