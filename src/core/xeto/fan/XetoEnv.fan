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

  ** Repository of all installed xeto libs.
  ** Not available in browser environemnts.
  abstract LibRepo repo()

  ** Home directory where xeto software is installed
  ** Not available in browser environemnts.
  abstract File homeDir()

  ** Working directory - first directory in the path.  The workDir
  ** is used as default location for 'xeto init' to create new libs.
  ** Not available in browser environemnts.
  abstract File workDir()

  ** Default install directory for 'xeto install'.
  ** Default is the `workDir`
  ** Not available in browser environemnts.
  abstract File installDir()

  ** List of paths to search for libraries in both lib and src format
  ** Not available in browser environemnts.
  abstract File[] path()

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

  ** Implementation for Dict.dis
  @NoDoc abstract Str dictDis(Dict x, Str? def)

  ** Implementation for Dict.map
  @NoDoc abstract Dict dictMap(Dict x, |Obj,Str->Obj| f)

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Mode used to determine path
  @NoDoc abstract Str mode()

  ** Debug props
  @NoDoc abstract Str:Str debugProps()

  ** Debug dump
  @NoDoc abstract Void dump(OutStream out := Env.cur.out)

  ** Main to debug dump
  @NoDoc static Void main() { echo; cur.dump; echo }

}

