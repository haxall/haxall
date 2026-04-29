//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2024  Brian Frank  Creation
//

using util
using xeto

**************************************************************************
** RepoCmd
**************************************************************************

internal class RepoCmd : XetoCmd
{
  override Str cmdName() { "repo" }

  override Str summary() { "List locally installed libs" }

  @Opt { help = "List all the installed versions"; aliases=["v"] }
  Bool versions

  @Opt { help = "Full listing including file and dependencies"; aliases=["f"] }
  Bool full

  @Arg { help = "Specific lib name or names to dump" }
  Str[]? libs

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto repo            // list all libs as table")
    out.printLine("  xeto repo sys        // list specific lib")
    out.printLine("  xeto repo sys ph     // list multiple libs")
    out.printLine("  xeto repo sys -full  // list full details of a specific lib")
    out.printLine("  xeto repo -full      // list full details of all libs")
    return 1
  }

  override Int run()
  {
    // find libs to list
    repo := XetoEnv.cur.repo
    LibVersion[]? list
    list = libs == null ?
           repo.libs :
           libs.map |n->LibVersion| { repo.lib(n) }

    // use table if not full
    asTable := !full
    if (asTable)
    {
      table := Obj[,]
      table.add(["name", "version", "doc"])
      list.each |x|
      {
        table.add([x.name, x.version.toStr, x.doc.truncate(48, "...")])
      }
      Console.cur.table(table)
    }
    else
    {
      echo
      list.each |x| { printFull(x) }
      echo
    }
    return 0
  }

  private Void printFull(LibVersion x)
  {
    echo("$x.name")
    echo("  Version: $x.version")
    echo("  File:    $x.file.osPath")
    echo("  Doc:     $x.doc")
    if (x.origin != null) echo("  Origin: $x.origin")
    echo("  Depends: " + x.depends.join(", "))
  }
}

