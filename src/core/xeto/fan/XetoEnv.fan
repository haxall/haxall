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
      curRef = Slot.findMethod("xetom::MEnv.init").call
    catch (Err e)
      Console.cur.err("Cannot init XetoEnv", e)
  }

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  ** Is this a remote namespace loaded over a network transport.
  ** Remote environments must load libraries asynchronously and do
  ** not support the full feature set.
  @NoDoc abstract Bool isRemote()

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

  ** Build varaibles
  abstract Str:Str buildVars()

//////////////////////////////////////////////////////////////////////////
// Namespace
//////////////////////////////////////////////////////////////////////////

  ** Construct a namespace for the given set of lib versions for this env.
  ** This method does not solve the dependency graph.  The list of lib
  ** versions passed must be a complete dependency tree that satisifies
  ** all version constraints.
  abstract Namespace createNamespace(LibVersion[] libs)

  ** Given a list of library names, map to latest versions, solve
  ** their dependency graph and create a namespace.
  @NoDoc abstract Namespace createNamespaceFromNames(Str[] names)

  ** Given a set of a records with a 'spec' tag, determine which libs
  ** are used and resolve them to libs and build a namespace.
  @NoDoc abstract Namespace createNamespaceFromData(Dict[] recs)

//////////////////////////////////////////////////////////////////////////
// Serialization
//////////////////////////////////////////////////////////////////////////

  ** Serialize a set of libs using xeto binary I/O to hydrate later
  @NoDoc abstract Void saveLibs(OutStream out, Lib[] libs)

  ** Deserialize a set of libs using xeto binary I/O into my cache.
  ** Ignore any libs I already have cached.  Return list of libs
  ** which we read (including those which were already loaded)
  @NoDoc abstract LibVersion[] loadLibs(InStream in)

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

  ** Implementation for Dict.dis
  @NoDoc abstract Str dictDis(Dict x)

  ** Implementation for Dict.toStr
  @NoDoc abstract Str dictToStr(Dict x)

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

