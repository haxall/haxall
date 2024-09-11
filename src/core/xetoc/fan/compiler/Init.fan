//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2023  Brian Frank  Creation
//

using util

**
** Initialize base class
**
internal abstract class Init : Step
{
  override Void run()
  {
    // check names
    if (compiler.ns != null) compiler.names = compiler.ns.names
    if (compiler.names == null) throw err("Compiler names not configured", FileLoc.inputs)

    // check namespace
    if (compiler.ns == null && nsRequired) throw err("Compiler ns not configured", FileLoc.inputs)

    // check input exists
    input := compiler.input
    if (input == null) throw err("Compiler input not configured", FileLoc.inputs)
    if (!input.exists) throw err("Input file not found: $input", FileLoc.inputs)
  }

  virtual Bool nsRequired() { true }
}

**************************************************************************
** InitLib
**************************************************************************

**
** Initialize to compileLib
**
internal class InitLib : Init
{
  override Void run()
  {
    // base class checks
    super.run

    // default libName to directory
    if (compiler.libName == null)
      compiler.libName = compiler.input.name

    // set flags
    compiler.isLib = true
    compiler.isSys = compiler.libName == "sys"
    compiler.isSysComp = compiler.libName == "sys.comp"
  }
}


**************************************************************************
** InitLibVersion
**************************************************************************

**
** Initialize to parseLibVersion
**
internal class InitLibVersion : InitLib
{
  override Bool nsRequired() { false }
}

**************************************************************************
** InitData
**************************************************************************

**
** Initialize for compileData
**
internal class InitData : Init
{
  override Void run()
  {
    // base class checks
    super.run

    // set flags
    compiler.isLib = false
    compiler.isSys = false
  }
}

