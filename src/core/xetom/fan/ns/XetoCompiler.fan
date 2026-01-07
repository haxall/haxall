//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Mar 2022  Brian Frank  Creation
//  26 Jan 2023  Brian Frank  Repurpose ProtoCompiler
//  18 Aug 2025  Brian Frank  Split public API into xetom
//

using xeto

**
** Xeto compiler API
**
@Js
abstract class XetoCompiler
{
  ** Initialize impelemntation
  static XetoCompiler init(|XetoCompiler| f)
  {
    c := Type.find("xetoc::MXetoCompiler").make
    f(c)
    return c
  }

  ** Namespace used for depends resolution
  MNamespace? ns

  ** Environment
  XetoEnv env := XetoEnv.cur

  ** Logging
  XetoLog log := XetoLog.makeOutStream

  ** Input as in-memory file, zip file, or source directory
  File? input

  ** Dotted name of library to compile
  Str? libName

  ** If set, then build this libraries xetolib zip to this file
  File? build

  ** Are we building a xetolib zip
  Bool isBuild() { build != null }

  ** Build vars from source environment
  Str:Str srcBuildVars() { env.buildVars }

  ** Apply options
  abstract Void applyOpts(Dict? opts)

  ** Compile input directory to library
  abstract Lib compileLib()

  ** Parse dict AST representation
  abstract Dict readAst()

  ** Compile input to instance data
  abstract Obj? readData()

  ** Parse only the lib.xeto file into version, doc, and depends.
  ** Must setup libName and input to the "lib.xeto" file
  abstract LibVersion parseLibMeta()

}

