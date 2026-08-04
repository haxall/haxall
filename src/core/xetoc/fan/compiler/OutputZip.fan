//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2023  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Output xetolib zip file
**
@Js
internal class OutputZip : Step
{
  override Void run()
  {
    if (!needToRun) return

    srcDir  := compiler.input
    zipFile := compiler.build

    zipFile.parent.create
    try
      XetoZipUtil.writeLibZip(zipFile.out, lib.name, lib.version, depends.list, lib.meta, compiler.usedBuildVars, XetoZipUtil.dirFiles(srcDir))
    catch (Err e)
      throw err("Cannot write xetolib zip '$zipFile': $e", FileLoc(srcDir), e)
  }

  private Bool needToRun()
  {
    // we only output zip in build mode
    if (!compiler.isBuild) return false

    return true
  }
}
