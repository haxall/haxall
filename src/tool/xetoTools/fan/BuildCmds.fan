//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2023  Brian Frank  Creation
//

using util
using data
using xeto

internal class BuildCmd : XetoCmd
{
  @Arg { help = "Libs to build or \"all\" to rebuild all source libs" }
  Str[]? libs

  override Str name() { "build" }

  override Str summary() { "Compile xeto source to xetolib" }

  override Int run()
  {
    if (libs == null || libs.isEmpty)
    {
      printLine("ERROR: no libs specified")
      return 1
    }
    qnames := libs.contains("all") ? env.libsInstalled : libs
    return env.build(qnames)
  }
}