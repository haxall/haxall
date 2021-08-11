//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2015  Brian Frank  Creation
//

using inet

**
** Main
**
class Main
{
  static Void main(Str[] args)
  {
    if (args.size < 4)
    {
      echo("usage:")
      echo("  ftp <user> <pass> <uri> <cmd>")
      echo("commands:")
      echo("  list")
      echo("  read")
      echo("  write")
      return
    }

    user := args[0]
    pass := args[1]
    uri  := args[2].toUri
    cmd  := args[3]

    c := FtpClient(user, pass)
    c.log.level = LogLevel.debug

    switch (cmd)
    {
      case "list":
        echo(c.list(uri).join("\n"))
      case "read":
        echo(c.read(uri).readAllStr)
      case "write":
        c.write(uri).print("test write $DateTime.now").close
      default:
        echo("Invalid cmd: $cmd")
    }
  }
}