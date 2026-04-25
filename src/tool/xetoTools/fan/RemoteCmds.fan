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

  RemoteRepoRegistry registry() { env.remoteRepos }
}

**************************************************************************
** RepoRemoteCmd
**************************************************************************

**
** RepoRemoteCmd handles standard logic to -repo or -r option
**
internal abstract class RepoRemoteCmd : RemoteCmd
{
  @Opt { help = "Name of repo to ping (if not default)"; aliases = ["r"] }
  Str? repo

  ** Get name for repo safely for error reporting
  Str getRepoName()
  {
    if (repo == null)
      return registry.def(false)?.name ?: "---"
    else
      return repo
  }

  ** Get the repo from option or default
  RemoteRepo getRepo()
  {
    if (repo == null)
      return registry.def
    else
      return registry.get(repo)
  }
}

**************************************************************************
** RemoteListCmd
**************************************************************************

internal class RemoteListCmd : RemoteCmd
{
  override Str cmdName() { "remote-list" }

  override Str[] aliases() { ["rl"] }

  override Str summary() { "List configured remote repos in registry" }

  @Opt { help = "Include pathDir in the listing" }
  Bool pathDir

  override Int run()
  {
    repos := registry.list

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

  override Str[] aliases() { ["ra"] }

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

      r := registry.add(name, uri.toUri, Etc.dictFromMap(meta), Etc.dictFromMap(opts))
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

  override Str[] aliases() { ["rr"] }

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

      registry.remove(name, Etc.dictFromMap(opts))
      return ok("Removed [$name]")
    }
    catch (Err e)
    {
      return err("Remove failed [$name]", e)
    }
  }
}

**************************************************************************
** RemotePingCmd
**************************************************************************

internal class RemotePingCmd : RepoRemoteCmd
{
  override Str cmdName() { "remote-ping" }

  override Str[] aliases() { ["rp"] }

  override Str summary() { "Ping a remote repo to ensure connectivity" }

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto remote-ping  // ping default remote repo")
    out.printLine("  xeto rp           // using command alias")
    out.printLine("  xeto rp -r acme   // ping remote repo named 'acme'")
    return 1
  }

  override Int run()
  {
    try
    {
      r := getRepo
      meta := r.ping
      ok("Ping success [$r.name]")
      Etc.dictDump(meta)
      return 0
    }
    catch (Err e)
    {
      return err("Ping failed [$getRepoName]", e)
    }
  }
}

**************************************************************************
** RemoteSearchCmd
**************************************************************************

internal class RemoteSearchCmd : RepoRemoteCmd
{
  override Str cmdName() { "remote-search" }

  override Str[] aliases() { ["rs"] }

  override Str summary() { "Ping a remote repo to ensure connectivity" }

  @Arg { help = "Query string for libs to search" }
  Str? query

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto remote-search foo  // search for 'foo' in default remote repo")
    out.printLine("  xeto rs foo             // using command alias")
    out.printLine("  xeto rs -r acme foo     // search for 'foo' in repo named 'acme'")
    return 1
  }

  override Int run()
  {
    try
    {
      r := getRepo
      req := LibRepoSearchReq(query)
      res := r.search(req)
      ok("Search success [$r.name]")
      return 0
    }
    catch (Err e)
    {
      return err("Search failed [$getRepoName]", e)
    }
  }
}

