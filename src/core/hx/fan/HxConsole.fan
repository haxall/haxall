//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 May 2026  Brian Frank  May the 4th be with you
//

using util

**
** Haxall console is the a simple terminal UI launched by a Runtime using
** the '-console' flag.  It always runs within the same process as the
** runtime itself.
**
@NoDoc
abstract const class HxConsole : Console
{

  ** System runtime
  abstract Sys sys()

  ** Current working project or err/null if sys is the current
  abstract Proj? proj(Bool checked := true)

  ** Current runtime which is proj if available or fallback to sys
  Runtime rt() { proj(false) ?: sys }

  ** List commands for current project
  abstract HxConsoleCmd[] cmds()

  ** Lookup command for current project
  abstract HxConsoleCmd? cmd(Str name, Bool checked := true)

  ** Enter the console read-eval-print loop and block forever until quit
  abstract Int run()

}

**************************************************************************
** HxConsoleCmd
**************************************************************************

**
** Implements one HxConsole command keyed by its name
**
@NoDoc
abstract const class HxConsoleCmd
{
  ** Name key for the command
  abstract Str name()

  ** Help string
  abstract Str help()

  ** Print usage
  virtual Void usage(HxConsole c) { c.info("$name  $help") }

  ** Aliases for the command
  virtual Str[] aliases() { Str#.emptyList }

  ** Execute with given input text which includes everything *after* command name
  abstract Void execute(HxConsole c, Str input)
}

