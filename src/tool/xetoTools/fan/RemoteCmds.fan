//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Apr 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetom
using xetodoc


**
** Base class for doc commands
**
internal abstract class RemoteCmd : XetoCmd
{
  XetoEnv env() { XetoEnv.cur }
}

**************************************************************************
** RemoteListCmd
**************************************************************************

internal class RemoteListCmd : RemoteCmd
{
  override Str cmdName() { "remote-list" }

  override Str summary() { "List configured remote repos in registry" }

  @Opt { help = "Include pathDir in the listing" }
  Bool pathDir

  override Int run()
  {
    repos := env.remoteRepos.list

    table := Obj[,]

    header := ["name", "uri"]
    if (pathDir) header.add("pathDir")
    header.add("notes")
    table.add(header)

    repos.each |r, i|
    {
      notes := i == 0 ? "default" : ""
      row := [r.name, r.uri.toStr]
      if (pathDir) row.add(r.pathDir.osPath)
      row.add(notes)
      table.add(row)
    }

    Console.cur.table(table)
    return 0
  }
}

**************************************************************************
** RemoteAddCmd
**************************************************************************

internal class RemoteAddCmd : RemoteCmd
{
  override Str cmdName() { "remote-add" }

  override Str summary() { "Configure a new remote repo in registry" }

  @Arg { help = "Name used to uniquely identify the repo in operations" }
  Str? name

  @Arg { help = "URI for the repo endpoint" }
  Str? uri

  @Opt { help = "Specify config dir in path (default is workDir)" }
  File? pathDir

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    n := cmdName
    out.printLine("Examples:")
    out.printLine("  xeto remote-add acme https://acme.com/")
    return 1
  }

  override Int run()
  {
    try
    {
      meta := Str:Obj[:]

      opts := Str:Obj[:]
      opts.setNotNull("pathDir", pathDir)

      r := env.remoteRepos.add(name, uri.toUri, Etc.dictFromMap(meta), Etc.dictFromMap(opts))
      return ok("Added $r.name.toCode")
    }
    catch (Err e)
    {
      return err("Remove failed", e)
    }
  }
}

**************************************************************************
** RemoteRemoveCmd
**************************************************************************

internal class RemoteRemoveCmd : RemoteCmd
{
  override Str cmdName() { "remote-remove" }

  override Str summary() { "Remove a remote repo from registry" }

  @Arg { help = "Name of repo to remove" }
  Str? name

  @Opt { help = "Allow remove from any dir in path (workDir only by default)" }
  Bool anyPathDir

  override Int run()
  {
    try
    {
      opts := Str:Obj[:]
      opts.setNotNull("anyPathDir", Marker.fromBool(anyPathDir))

      env.remoteRepos.remove(name, Etc.dictFromMap(opts))
      return ok("Removed $name.toCode")
    }
    catch (Err e)
    {
      return err("Remove failed", e)
    }
  }
}

