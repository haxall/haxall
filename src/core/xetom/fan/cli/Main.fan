//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Mar 2023  Brian Frank  Creation
//

using util

**
** Xeto CLI tools
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
    cmd := XetoCmd.find(cmdName)
    if (cmd == null)
    {
      echo("ERROR: unknown xeto command '$cmdName'")
      return 1
    }

    // strip command from args and process as util::AbstractMain
    return cmd.main(args.dup[1..-1])
  }
}

