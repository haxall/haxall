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
** EmvCmd
**************************************************************************

internal class EnvCmd : XetoCmd
{
  override Str name() { "env" }

  override Str summary() { "Dump environment and installed libs" }

  override Int run()
  {
    env.dump
    return 0
  }
}

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
    env := Env.cur
    envPath := [env.workDir]
    if (env is PathEnv) envPath = ((PathEnv)env).path

    printLine
    printLine("Xeto CLI Tools")
    printLine("Copyright (c) 2022-${Date.today.year}, SkyFoundry LLC")
    printLine("Licensed under the Academic Free License version 3.0")
    printLine
    printLine("xeto.version:     " + typeof.pod.version)
    printLine("java.version:     " + Env.cur.vars["java.version"])
    printLine("java.vm.name:     " + Env.cur.vars["java.vm.name"])
    printLine("java.vm.vendor:   " + Env.cur.vars["java.vm.vendor"])
    printLine("java.vm.version:  " + Env.cur.vars["java.vm.version"])
    printLine("java.home:        " + Env.cur.vars["java.home"])
    printLine("fan.version:      " + Pod.find("sys").version)
    printLine("fan.platform:     " + Env.cur.platform)
    printLine("fan.env.path:     " + envPath.join(", ") { it.osPath })
    printLine
    return 0
  }
}

