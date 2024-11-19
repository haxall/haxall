//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jan 2023  Brian Frank  Creation
//

using axon
using util

**
** Axon shell command line interface program
**
class Main
{
  OutStream out := Env.cur.out

  Int main(Str[] mainArgs)
  {
    // short circuiting options
    opts := mainArgs.findAll { it.startsWith("-") }
    args := mainArgs.findAll { !it.startsWith("-") }
    if (hasOpt(opts, "-help", "-?")) return printHelp
    if (hasOpt(opts, "-version", "-v")) return printVersion

    // if no args, then enter interactive shell
    cx := ShellContext(out)
    if (args.isEmpty) return cx.runInteractive

    // arg is either expression or axon file name
    arg := args[0]

    // setup shell args with everything after file name
    cx.defOrAssign("args", mainArgs[mainArgs.index(arg)+1..-1], Loc("main"))

    // if first arg is axon file, then run it as script
    if (arg.endsWith(".axon"))
    {
      // read script in as expression
      arg = File.os(arg).readAllStr

      // strip shebang
      if (arg.startsWith("#!")) arg = arg.splitLines[1..-1].join("\n")
    }

    errnum := cx.run(arg)
    if (hasOpt(opts, "-i"))
      return cx.runInteractive
    else
      return errnum
  }

  Bool hasOpt(Str[] opts, Str name, Str? abbr := null)
  {
    opts.any { it == name || it == abbr }
  }

  Int printHelp()
  {
    out.printLine
    out.printLine("Usage:")
    out.printLine("  axon              Start interactive shell")
    out.printLine("  axon file         Execute axon script from file")
    out.printLine("  axon 'expr'       Evaluate axon expression")
    out.printLine("  axon 'expr' -i    Eval axon and then enter interactive shell")
    out.printLine("Options:")
    out.printLine("  -help, -?         Print usage help")
    out.printLine("  -version, -v      Print version info")
    out.printLine("  -i                Enter interactive shell after eval")
    out.printLine
    return 0
  }

  private Int printVersion()
  {
    props := Str:Obj[:] { ordered = true }
    props["axon.version"] = typeof.pod.version.toStr
    AbstractMain.runtimeProps(props)

    out := Env.cur.out
    out.printLine
    out.printLine("Axon Shell")
    out.printLine("Copyright (c) 2022-${Date.today.year}, SkyFoundry LLC")
    out.printLine("Licensed under the Academic Free License version 3.0")
    out.printLine
    AbstractMain.printProps(props, ["out":out])
    out.printLine

    return 0
  }

}

