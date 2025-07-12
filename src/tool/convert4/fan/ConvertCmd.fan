//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util
using haystack

**
** Convert to 4.0 CLI command plugin.
**
abstract class ConvertCmd : AbstractMain
{
  ** Find a specific command or return null
  static ConvertCmd? find(Str name)
  {
    list.find |cmd| { cmd.name == name || cmd.aliases.contains(name) }
  }

  ** List installed commands
  static ConvertCmd[] list()
  {
    acc := ConvertCmd[,]

    // this pod
    ConvertCmd#.pod.types.each |t|
    {
      if (t.fits(ConvertCmd#) && !t.isAbstract) acc.add(t.make)
    }

    // other pods via index
    Env.cur.index("convert4.cmd").each |qname|
    {
      try
      {
        type := Type.find(qname)
        cmd := (ConvertCmd)type.make
        acc.add(cmd)
      }
      catch (Err e) echo("ERROR: invalid convert4.cmd $qname\n  $e")
    }

    acc.sort |a, b| { a.name <=> b.name }
    return acc
  }

  ** App name is "convert4 {name}"
  override final Str appName() { "convert4 $name" }

  ** Log name is "convert4"
  override Log log() { Log.get("convert4") }

  ** Command name
  abstract Str name()

  ** Command name alises/shortcuts
  virtual Str[] aliases() { Str[,] }

  ** Name and aliases
  Str[] names() { [name].addAll(aliases) }

  ** Run the command.  Return zero on success
  abstract override Int run()

  ** Single line summary of the command for help
  abstract Str summary()

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Print a line to stdout
  Void printLine(Str line := "") { echo(line) }

  ** Output to a file or stdout and guaranteed closed
  Void withOut(File? arg, |OutStream| f)
  {
    if (arg == null)
    {
      f(Env.cur.out)
    }
    else
    {
      printLine("Write [$arg.osPath]")
      out := arg.out
      try
        f(out)
      finally
        out.close
    }
  }

  ** Prompt for a confirm yes/no
  Bool promptConfirm(Str msg)
  {
    res := Env.cur.prompt("$msg (y/n)> ")
    if (res.lower == "y") return true
    return false
  }

}

