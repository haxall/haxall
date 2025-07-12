//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util


internal class ConvertExtCmd : ConvertCmd
{
  override Str name() { "ext" }

  override Str summary() { "Convert hx::HxLib to Ext" }

  @Arg Str[] commandName := [,]

  override Int run()
  {
    printLine("TODO")
    printLine
    return 0
  }
}

