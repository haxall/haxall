//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Mar 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** Xeto CLI command plugin.  To create:
**
**  1. Define subclass of XetoCmd
**  2. Register type qname via indexed prop as "xeto.cmd" (if not in this pod)
**  3. Annotate options and args using `util::AbstractMain` design
**
abstract class XetoCmd : AbstractMain
{
  ** Find a specific command or return null
  static XetoCmd? find(Str name)
  {
    list.find |cmd| { cmd.name == name || cmd.aliases.contains(name) }
  }

  ** List installed commands
  static XetoCmd[] list()
  {
    acc := XetoCmd[,]

    // this pod
    XetoCmd#.pod.types.each |t|
    {
      if (t.fits(XetoCmd#) && !t.isAbstract) acc.add(t.make)
    }

    // xetoTools pod
    xetoTools := Pod.find("xetoTools", false)
    if (xetoTools != null)
    {
      xetoTools.types.each |t|
      {
        if (t.fits(XetoCmd#) && !t.isAbstract) acc.add(t.make)
      }
    }

    // other pods via index
    Env.cur.index("xeto.cmd").each |qname|
    {
      try
      {
        type := Type.find(qname)
        cmd := (XetoCmd)type.make
        acc.add(cmd)
      }
      catch (Err e) echo("ERROR: invalid xeto.cmd $qname\n  $e")
    }

    acc.sort |a, b| { a.name <=> b.name }
    return acc
  }

  ** App name is "xeto {name}"
  override final Str appName() { "xeto $name" }

  ** Log name is "xeto"
  override Log log() { Log.get("xeto") }

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
// I/O
//////////////////////////////////////////////////////////////////////////

  ** Read an input file of dicts from any format
  Dict[] readInputFile(File? file)
  {
    if (file == null || !file.exists) throw Err("Input file does not exist: $file")
    switch (file.ext)
    {
      case "trio": return TrioReader(file.in).readAllDicts
      case "zinc": return Etc.toRecs(ZincReader(file.in).readVal)
      case "json": return Etc.toRecs(JsonReader(file.in).readVal)
      default: throw Err("Unsupported input file extension: $file")
    }
  }

  ** Output grid to given file extension
  Void writeOutputFile(File file, Grid grid)
  {
    buf := StrBuf()
    out := buf.out
    switch (file.ext)
    {
      case "trio": TrioWriter(out).writeGrid(grid).close
      case "zinc": ZincWriter(out).writeGrid(grid).close
      case "json": JsonWriter(out).writeGrid(grid).close
      default: throw Err("Unsupported input file extension: $file")
    }
    str := buf.toStr

    if (file.basename == "stdout")
    {
      Env.cur.out.printLine(str)
    }
    else
    {
      file.out.print(str).close
      echo("Wrote Output [$file.osPath]")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Print a line to stdout
  Void printLine(Str line := "") { echo(line) }

  ** Print error message and return 1
  Int err(Str msg) { printLine("ERROR: $msg"); return 1 }

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

