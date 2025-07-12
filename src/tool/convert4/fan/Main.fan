//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util

**
** Convert to 4.0 CLI tools
**
class Main
{
  static Int main(Str[] args) { doMain(args) }

  static Int doMain(Str[] args)
  {
    // special handling for help/version without cluttering up help listing
    if (args.isEmpty || args.first == "-?" || args.first == "-help" || args.first == "--help") args = ["help"]
    else if (args.first == "-version" || args.first == "--version") args = ["version"]

    // lookup command
    cmdName := args.first
    cmd := ConvertCmd.find(cmdName)
    if (cmd == null)
    {
      echo("ERROR: unknown command '$cmdName'")
      return 1
    }

    // strip command from args and process as util::AbstractMain
    return cmd.main(args.dup[1..-1])
  }
}

