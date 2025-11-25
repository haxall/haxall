//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util

**************************************************************************
** HelpCmd
**************************************************************************

internal class HelpCmd : ConvertCmd
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
      if (cmd == null) { echo("ERROR: Unknown help command '$cmdName'"); return 1 }
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
    printLine("Convert to 4.0 CLI Tools:")
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
** VersionCmd
**************************************************************************

internal class VersionCmd : ConvertCmd
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
    out.printLine("Convert 4.0 CLI Tools")
    out.printLine("Copyright (c) 2024-${Date.today.year}, SkyFoundry LLC")
    out.printLine("Licensed under the Academic Free License version 3.0")
    out.printLine
    printProps(props, ["out":out])
    out.printLine
    return 0
  }
}

**************************************************************************
** DumpCmd
**************************************************************************

internal class DumpCmd : ConvertCmd
{
  override Str name() { "dump" }

  override Str summary() { "Dump status of source environment" }

  @Opt { help = "Dump pods" }
  Bool pods := false

  @Opt { help = "Dump extensions" }
  Bool exts := false

  @Opt { help = "Dump functions" }
  Bool funcs := false

  @Opt { help = "Dump everything" }
  Bool all := false

  @Arg Str[] commandName := [,]

  override Int run()
  {
    ast := Ast().scanWorkDir
    if (all) { ast.dump; return 0 }
    if (pods)  ast.dumpPods
    if (exts)  ast.dumpExts
    if (funcs) ast.dumpFuncs
    return 0
  }
}

**************************************************************************
** WrapFuncsCmd
**************************************************************************

internal class WrapFuncsCmd : ConvertCmd
{
  override Str name() { "wrapFuncs" }

  override Str summary() { "Wrap all old style globals funcs in +Funcs mixin" }

  override Int run()
  {
    files := File[,]
    findFiles(files, Env.cur.workDir + `src/xeto/`)

    files.each |f|
    {
      try
        fix(f)
      catch (Err e)
        Console.cur.err("ERROR: cannot fix file [$f.osPath]", e)
    }
    return 0
  }

  Void fix(File f)
  {
    echo("Fix [$f.osPath]")
    lines := f.readAllLines
    start := lines.findIndex { it.trim.isEmpty } ?: throw Err("No blank lines")
    lines = lines.map |line, i->Str|
    {
      if (i < start || line.trim.isEmpty) return line
      return "  " + line
    }
    lines.insert(start+1, "+Funcs {")
    if (!lines[start+2].trim.isEmpty) lines.insert(start+2, "")
    lines.add("}").add("")
    f.out.print(lines.join("\n")).close
  }

  Void findFiles(File[] acc, File f)
  {
    if (f.name == "funcs.xeto") acc.add(f)
    if (f.isDir) f.list.each |kid| { findFiles(acc, kid) }
  }
}

