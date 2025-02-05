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
    Str[] names := cmds.map |cmd->Str| { cmd.names.join(", ") }
    maxName := 4
    names.each |n| { maxName = maxName.max(n.size) }

    // print help
    printLine
    printLine("Xeto CLI Tools:")
    printLine
    list.each |cmd, i|
    {
      printLine(names[i].padr(maxName) + "  " + cmd.summary)
    }
    printLine
    return 0
  }
}

**************************************************************************
** EnvCmd
**************************************************************************

internal class EnvCmd : XetoCmd
{
  override Str name() { "env" }

  override Str summary() { "Print environment and lib path info" }

  override Int run()
  {
    out := Env.cur.out
    out.printLine
    printProps(XetoEnv.cur.debugProps, ["out":out])
    out.printLine
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
    runtimeProps(props)

    out := Env.cur.out
    out.printLine
    out.printLine("Xeto CLI Tools")
    out.printLine("Copyright (c) 2022-${Date.today.year}, SkyFoundry LLC")
    out.printLine("Licensed under the Academic Free License version 3.0")
    out.printLine
    printProps(props, ["out":out])
    out.printLine
    printProps(XetoEnv.cur.debugProps, ["out":out])
    out.printLine
    return 0
  }
}

