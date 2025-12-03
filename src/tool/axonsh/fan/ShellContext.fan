//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jan 2023  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetom::Printer
using axon
using def
using hx
using hxm

**
** Shell context
**
class ShellContext : Context
{
  ** Constructor
  new make(ShellSys sys, User user, OutStream out := Env.cur.out)
    : super(sys, null, user)
  {
    this.out = out
  }

  ** Run the iteractive prompt+eval loop
  Int runInteractive()
  {
    out.printLine("Axon shell v${typeof.pod.version} ('?' for help, 'quit' to quit)")
    while (!isDone)
    {
      try
      {
        expr := prompt
        if (!expr.isEmpty) run(expr)
      }
      catch (SyntaxErr e)
      {
        err("Syntax Error: $e.msg")
      }
      catch (EvalErr e)
      {
        err(e.msg, e.cause)
      }
      catch (Err e)
      {
        err(e.toStr, e)
      }
    }
    return 0
  }

  ** Run the given expression and handle errors/output
  Int run(Str expr)
  {
    // wrap list of expressions in do/end block
    if (expr.contains(";") || expr.contains("\n"))
      expr = "do\n$expr\nend"

    // evaluate the expression
    Obj? val
    try
    {
      val = eval(expr)
    }
    catch (EvalErr e)
    {
      err(e.msg, e.cause)
      return 1
    }

    // print the value if no echo
    if (val !== noEcho) print(val)

    // save last value as "it"
    if (val != null && val != noEcho) defOrAssign("it", val, Loc.eval)
    return 0
  }

  ** Prompt user for input
  private Str prompt()
  {
    // prompt for one or more lines
    expr := Env.cur.prompt("axon> ").trim

    // if it looks like expression is incomplete, then
    // prompt for additional lines until empty
    if (isMultiLine(expr))
    {
      x := StrBuf().add(expr).add("\n")
      while (true)
      {
        next := Env.cur.prompt("..... ")
        if (next.trim.isEmpty) break
        x.add(next).add("\n")
      }
      expr = x.toStr
    }

    // check for special commands
    switch (expr)
    {
      case "?":
      case "help": return "help()"
      case "bye":
      case "exit":
      case "quit": return "quit()"
    }

    return expr
  }

  ** Return if we should enter multi-line input mode
  private Bool isMultiLine(Str expr)
  {
    if (expr.endsWith("do")) return true
    if (expr.endsWith("{")) return true
    return false
  }

  ** Print the value to the stdout
  Void print(Obj? val, Dict? opts := null)
  {
    printer(opts).print(val)
  }

  ** Log evaluation error
  private Obj? err(Str msg, Err? err := null)
  {
    str := errToStr(msg, err)
    if (!str.endsWith("\n")) str += "\n"
    printer.warn(str)
    return null
  }

  ** Format evaluation error trace
  private Str errToStr(Str msg, Err? err)
  {
    str := "ERROR: $msg"
    if (err == null) return str
    if (err is FileLocErr) str += " [" + ((FileLocErr)err).loc + "]"
    if (showTrace) str += "\n" + err.traceToStr
    else if (!str.contains("\n")) str += "\n" + err.toStr
    return str
  }

  ** Flag for full stack trace dumps
  Bool showTrace := true

  ** Sentinel value for no echo
  static const Str noEcho := "_no_echo_"

  ** Standout output stream
  OutStream out { private set }

  ** Create Xeto printer for output stream
  Printer printer(Dict? opts := null) { Printer(ns, out, opts ?: Etc.dict0) }

  ** Flag to terminate the interactive loop
  Bool isDone := false

}

