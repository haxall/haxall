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
  static Int main(Str[] args)
  {
    // lookup command
    if (args.isEmpty || args.first == "-?" || args.first == "-help" || args.first == "--help") args = ["help"]
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

