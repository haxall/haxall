//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Dec 2022  Brian Frank  Creation
//

using axon
using xeto::Printer
using util

**
** Axon shell session
**
internal class ShellSession
{
  new make(OutStream out)
  {
    this.out = out
    this.cx  = ShellContext(this)
  }

  Int run()
  {
    out.printLine("Axon shell v${typeof.pod.version} ('?' for help, 'quit' to quit)")
    while (!isDone)
    {
      try
      {
        expr := prompt
        execute(expr)
      }
      catch (AxonErr e)
      {
        err(e.msg, e.cause)
      }
      catch (Err e)
      {
        err("Internal error", e)
      }
    }
    return 0
  }

  Int eval(Str expr)
  {
    // wrap list of expressions in do/end block
    if (expr.contains(";") || expr.contains("\n"))
      expr = "do\n$expr\nend"

    // evaluate the expression
    Obj? val
    try
    {
      val = cx.eval(expr)
    }
    catch (EvalErr e)
    {
      err(e.msg, e.cause)
      return 1
    }

    // print the value if no echo
    if (val !== noEcho) print(val)

    // save last value as "it"
    if (val != null && val != noEcho) cx.defOrAssign("it", val, Loc.eval)
    return 0
  }

  Void print(Obj? val, Obj? opts := null)
  {
    cx.data.print(val, out, opts)
  }

  Void setArgs(Str[] args)
  {
    cx.defOrAssign("args", args, Loc("main"))
  }

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

    return expr
  }

  private Bool isMultiLine(Str expr)
  {
    if (expr.endsWith("do")) return true
    if (expr.endsWith("{")) return true
    return false
  }

  private Void execute(Str expr)
  {
    // skip empty string
    if (expr.isEmpty) return

    // check for special commands
    switch (expr)
    {
      case "?":
      case "help": return help
      case "bye":
      case "exit":
      case "quit": return quit
    }

    // evaluate as axon
    eval(expr)
  }

  private Void help()
  {
    eval("help()")
  }

  private Void quit()
  {
    isDone = true
  }

  private Obj? err(Str msg, Err? err := null)
  {
    str := errToStr(msg, err)
    if (!str.endsWith("\n")) str += "\n"
    Printer(cx.data, out, cx.data.dict0).warn(str)
    return null
  }

  private Str errToStr(Str msg, Err? err)
  {
    str := "ERROR: $msg"
    if (err == null) return str
    if (err is FileLocErr) str += " [" + ((FileLocErr)err).loc + "]"
    if (showTrace) str += "\n" + err.traceToStr
    else if (!str.contains("\n")) str += "\n" + err.toStr
    return str
  }

  static const Str noEcho := "_no_echo_"

  OutStream out
  ShellContext cx
  Bool isDone := false
  Bool showTrace := false
  ShellDb db := ShellDb()
}

