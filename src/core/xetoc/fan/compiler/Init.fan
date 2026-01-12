//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2023  Brian Frank  Creation
//

using util
using xetom

**
** Initialize base class
**
@Js
internal abstract class Init : Step
{
  new make(CompileMode mode) { this.initMode = mode }

  const CompileMode initMode

  override Void run()
  {
    // set mode
    compiler.mode = initMode

    // check namespace
    if (compiler.ns == null && nsRequired) throw err("Compiler ns not configured", FileLoc.inputs)

    // check input exists
    input := compiler.input
    if (input == null) throw err("Compiler input not configured", FileLoc.inputs)
    if (!input.exists) throw err("Input file not found: $input", FileLoc.inputs)

    // initialize AST namespace instance
    compiler.cns = ANamespace(this)
  }

  virtual Bool nsRequired() { true }
}

**************************************************************************
** InitLib
**************************************************************************

**
** Initialize to compileLib
**
@Js
internal class InitLib : Init
{
  new make(CompileMode mode := CompileMode.lib) : super(mode) {}

  override Void run()
  {
    // base class checks
    super.run

    // default libName to directory
    if (compiler.libName == null)
      compiler.libName = compiler.input.name

    // set flags
    compiler.isSys       = compiler.libName == "sys"
    compiler.isSysComp   = compiler.libName == "sys.comp"
    compiler.isPh        = compiler.libName == "ph"
    compiler.isCompanion = compiler.libName == XetoUtil.companionLibName
  }
}

**************************************************************************
** InitData
**************************************************************************

**
** Initialize for readData
**
@Js
internal class InitData : Init
{
  new make() : super(CompileMode.data) {}
}

**************************************************************************
** InitParseToDicts
**************************************************************************

**
** Initialize to readAst
**
@Js
internal class InitAst : InitLib
{
  new make() : super(CompileMode.ast) {}

  override Bool nsRequired() { false }
}

**************************************************************************
** InitParseLibMeta
**************************************************************************

**
** Initialize to parseLibMeta
**
@Js
internal class InitParseLibMeta : InitLib
{
  new make() : super(CompileMode.parseLibMeta) {}

  override Bool nsRequired() { false }
}

