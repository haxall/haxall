//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jan 2023  Brian Frank  Creation
//

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
    session := ShellSession(out)
    if (args.isEmpty) return session.run

    // arg is either expression or axon file name
    arg := args[0]

    // setup shell args with everything after file name
    session.setArgs(mainArgs[mainArgs.index(arg)+1..-1])

    // if first arg is axon file, then run it as script
    if (arg.endsWith(".axon"))
    {
      // read script in as expression
      arg = File.os(arg).readAllStr

      // strip shebang
      if (arg.startsWith("#!")) arg = arg.splitLines[1..-1].join("\n")
    }

    errnum := session.eval(arg)
    if (hasOpt(opts, "-i"))
      return session.run
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
    out.printLine
    out.printLine("Axon Shell")
    out.printLine
    out.printLine("axon.version:  " + typeof.pod.version)
    out.printLine("java.version:  " + Env.cur.vars["java.version"])
    out.printLine("java.vm.name:  " + Env.cur.vars["java.vm.name"])
    out.printLine("java.home:     " + Env.cur.vars["java.home"])
    out.printLine("fan.version:   " + Pod.find("sys").version)
    out.printLine("fan.home:      " + Env.cur.homeDir.osPath)
    out.printLine
    return 0
  }

}

