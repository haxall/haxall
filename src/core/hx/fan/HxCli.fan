//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 2021  Brian Frank  Creation
//

using util

**
** Haxall command line interface.  To create a new hx command:
**
**  1. Define subclass of HxCli
**  2. Register type qname via indexed prop as "hx.cli"
**  3. Annotate options and args using `util::AbstractMain` design
**
abstract class HxCli : AbstractMain
{
  ** Find a specific command or return null
  static HxCli? find(Str name)
  {
    list.find |cmd| { cmd.name == name || cmd.aliases.contains(name) }
  }

  ** List installed commands
  static HxCli[] list()
  {
    acc := HxCli[,]
    Env.cur.index("hx.cli").each |qname|
    {
      try
      {
        type := Type.find(qname)
        cmd := (HxCli)type.make
        acc.add(cmd)
      }
      catch (Err e) echo("ERROR: invalid hx.cli $qname\n  $e")
    }
    acc.sort |a, b| { a.name <=> b.name }
    return acc
  }

  ** App name is "hx {name}"
  override final Str appName() { "hx $name" }

  ** Log name is "hx"
  override Log log() { Log.get("hx") }

  ** Command name
  abstract Str name()

  ** Command name alises/shortcuts
  virtual Str[] aliases() { Str[,] }

  ** Run the command.  Return zero on success
  abstract override Int run()

  ** Single line summary of the command for help
  abstract Str summary()

  ** Print a line to stdout
  Void printLine(Str line := "") { echo(line) }

  ** Print error message and return 1
  @NoDoc Int err(Str msg) { printLine("ERROR: $msg"); return 1 }
}

**************************************************************************
** Main
**************************************************************************

@NoDoc const class Main
{
  static Int main(Str[] args)
  {
    // lookup command
    if (args.isEmpty || args.first == "-?" || args.first == "-help" || args.first == "--help") args = ["help"]
    cmdName := args.first
    cmd := HxCli.find(cmdName)
    if (cmd == null)
    {
      echo("ERROR: unknown command '$cmdName'")
      return 1
    }

    // strip command from args and process as util::AbstractMain
    return cmd.main(args.dup[1..-1])
  }
}

**************************************************************************
** HelpCli
**************************************************************************

internal class HelpCli : HxCli
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
    printLine("Haxall CLI commands:")
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
** VersionCli
**************************************************************************

internal class VersionCli : HxCli
{
  override Str name() { "version" }
  override Str[] aliases() { ["-v"] }
  override Str summary() { "Print version info" }
  override Int run()
  {
    props := Str:Obj[:] { ordered = true }
    props["hx.version"] = typeof.pod.version.toStr
    runtimeProps(props)

    out := Env.cur.out
    out.printLine
    printLine("Haxall CLI")
    printLine("Copyright (c) 2009-${Date.today.year}, SkyFoundry LLC")
    printLine("Licensed under the Academic Free License version 3.0")
    out.printLine
    printProps(props, ["out":out])
    out.printLine

    return 0
  }
}

