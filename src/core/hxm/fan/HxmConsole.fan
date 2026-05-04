//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 May 2026  Brian Frank  May the 4th be with you
//

using concurrent
using util
using xeto
using xetom
using xetom::Printer
using axon
using haystack
using hx

**
** HxConsole implementation
**
const class HxmConsole : HxConsole
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Sys sys)
  {
    this.sys  = sys
    this.base = Console.cur
  }

//////////////////////////////////////////////////////////////////////////
// HxConsole
//////////////////////////////////////////////////////////////////////////

  override const Sys sys

  const Console base

  override Proj? proj(Bool checked := true)
  {
    p := projRef.val
    if (p != null) return p
    if (checked) throw Err("No proj selected")
    return null
  }
  private const AtomicRef projRef := AtomicRef()

  override HxConsoleCmd[] cmds()
  {
    acc := HxConsoleCmd[,]
    builtin(acc, "quit",  "Shutdown the runtime", ["q"])
    builtin(acc, "help",  "Print command list", ["?"])
    builtin(acc, "projs", "List projects")
    builtin(acc, "proj",  "Set current project")
    rt.exts.each |ext| { acc.addAll(ext.consoleCmds) }
    return acc.sort |a, b| { a.name <=> b.name }
  }

  override HxConsoleCmd? cmd(Str name, Bool checked := true)
  {
    cmd := cmds.find { it.name == name || it.aliases.contains(name) }
    if (cmd != null) return cmd
    if (checked) throw Err("Unknown console cmd: $name")
    return null
  }

  private Void builtin(HxConsoleCmd[] acc, Str name, Str help, Str[]? alias := null)
  {
    acc.add(HxmConsoleCmd(name, help, alias ?: Str#.emptyList))
  }

//////////////////////////////////////////////////////////////////////////
// Run Loop
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    while (true)
    {
      try
      {
        // prompt
        input := doPrompt.trim

        // if empty/quit
        if (input.isEmpty) continue
        if (input == "quit" || input == "q") return 0

        // get command name
        name := input
        sp := input.index(" ")
        if (sp != null)
        {
          name = input[0..<sp]
          input = input[sp+1..-1].trimStart
        }

        // find command
        cmd := cmd(name, false)
        if (cmd == null)
        {
          warn("Unknown command: $name")
          continue
        }

        // execute it
        cmd.execute(this, input)
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

  ** Prompt user for input
  private Str doPrompt()
  {
    // prompt for one or more lines
    prompt := "$rt.name>"
    input := Env.cur.prompt(prompt+" ").trim

    // if it looks like expression is incomplete, then
    // prompt for additional lines until empty
    if (isMultiLine(input))
    {
      x := StrBuf().add(input).add("\n")
      while (true)
      {
        next := Env.cur.prompt(".".mult(prompt.size)+" ")
        if (next.trim.isEmpty) break
        x.add(next).add("\n")
      }
      input = x.toStr
    }

    return input
  }

  ** Return if we should enter multi-line input mode
  private Bool isMultiLine(Str expr)
  {
    if (expr.endsWith("do")) return true
    if (expr.endsWith("{")) return true
    return false
  }

//////////////////////////////////////////////////////////////////////////
// Console
//////////////////////////////////////////////////////////////////////////

  override Int? width() { base.width }

  override Int? height() { base.height }

  override This debug(Obj? msg, Err? err := null) { base.debug(msg, err); return this }

  override This info(Obj? msg, Err? err := null) { base.info(msg, err); return this }

  override This warn(Obj? msg, Err? err := null) { base.warn(msg, err); return this }

  override This err(Obj? msg, Err? err := null) { base.err(msg, err); return this }

  override This table(Obj? obj) { base.table(obj); return this }

  override This clear() { base.clear; return this }

  override This group(Obj? msg, Bool collapsed := false) { base.group(msg, collapsed); return this }

  override This groupEnd() { base.groupEnd; return this }

  override Str? prompt(Str msg := "") { base.prompt(msg) }

  override Str? promptPassword(Str msg := "") { base.promptPassword(msg) }

//////////////////////////////////////////////////////////////////////////
// Commands
//////////////////////////////////////////////////////////////////////////

  Void onHelp(Str input)
  {
    t := Obj[,]
    t.add(["Name", "Help"])
    cmds.each |cmd|
    {
      n := cmd.name
      if (!cmd.aliases.isEmpty) n += ", " + cmd.aliases.join(", ")
      t.add([n, cmd.help])
    }
    table(t)
  }

  Void onProjs(Str input)
  {
    t := Obj[,]
    t.add(["Name"])
    sys.proj.list.each |p|
    {
      t.add([p.name])
    }
    table(t)
  }

  Void onProj(Str input)
  {
    projRef.val = input == "sys" ? null : sys.proj.get(input)
    info("Current proj is now '$rt.name'")
  }


}

**************************************************************************
** HxmConsoleCmd (for built-in commands)
**************************************************************************

internal const class HxmConsoleCmd : HxConsoleCmd
{
  new make(Str n, Str h, Str[] a) { name = n; help = h; aliases = a }
  const override Str name
  const override Str help
  const override Str[] aliases

  override Void execute(HxConsole c, Str cmd)
  {
    c.typeof.method("on" + name.capitalize).callOn(c, [cmd])
  }
}

