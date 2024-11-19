//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Mar 2023  Brian Frank  Creation
//

using util
using xeto

**************************************************************************
** HelpCmd
**************************************************************************

internal class HelpCmd : XetoCmd
{
  override Str name() { "help" }

  override Str[] aliases() { ["-h", "-?"] }

  override Str summary() { "Print listing of available commands" }

  @Arg Str[] commandName := [,]

  override Int run()
  {
    // if we have a command name, print its usage
    if (commandName.size > 0)
    {
      cmdName := commandName[0]
      cmd := find(cmdName)
      if (cmd == null) return err("Unknown help command '$cmdName'")
      printLine
      ret := cmd.usage
      printLine
      return ret
    }

    // show summary for all commands; find longest command name
    cmds := list
    maxName := 4
    cmds.each |cmd| { maxName = maxName.max(cmd.name.size) }

    // print help
    printLine
    printLine("Xeto CLI Tools:")
    printLine
    list.each |cmd|
    {
      printLine(cmd.name.padr(maxName) + "  " + cmd.summary)
    }
    printLine
    return 0
  }
}

**************************************************************************
** VersionCmd
**************************************************************************

internal class VersionCmd : XetoCmd
{
  override Str name() { "version" }

  override Str[] aliases() { ["-v"] }

  override Str summary() { "Print version info" }

  override Int run()
  {
    props := Str:Obj[:] { ordered = true }
    props["xeto.version"] = typeof.pod.version.toStr
    runtimeProps(props)

    out := Env.cur.out
    out.printLine
    out.printLine("Xeto CLI Tools")
    out.printLine("Copyright (c) 2022-${Date.today.year}, SkyFoundry LLC")
    out.printLine("Licensed under the Academic Free License version 3.0")
    out.printLine
    printProps(props, ["out":out])
    out.printLine
    return 0
  }
}

