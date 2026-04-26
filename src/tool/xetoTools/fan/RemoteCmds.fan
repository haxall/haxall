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

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto remote-list  // list the configured remote repos")
    out.printLine("  xeto rl           // use command alias")
    out.printLine("  xeto rl -pathDir  // include where config is defined in path")
    return 1
  }

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

  override Str summary() { "Search the libs of remote repo" }

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
      req := RemoteRepoSearchReq(query)
      res := r.search(req)

      table := Obj[,]
      table.add(["name", "latest", "doc"])
      res.libs.each |lib|
      {
        table.add([lib.name, lib.version.toStr, lib.doc])
      }
      Console.cur.table(table)

      ok("Search success [$r.name, $res.libs.size matches]")
      return 0
    }
    catch (Err e)
    {
      return err("Search failed [$getRepoName]", e)
    }
  }
}

**************************************************************************
** RemoteVersionsCmd
**************************************************************************

internal class RemoteVersionsCmd : RepoRemoteCmd
{
  override Str cmdName() { "remote-versions" }

  override Str[] aliases() { ["rv"] }

  override Str summary() { "Read version details from remote repo" }

  @Arg { help = "Lib name or name-version to query" }
  Str? name

  @Opt { help = "Max number to query" }
  Int limit := 1

  @Opt { help = "Version constraints" }
  Str? versions

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto remote-verions foo      // all versions of foo")
    out.printLine("  xeto rv foo                  // using command alias")
    out.printLine("  xeto rv foo -r acme foo      // from repo named 'acme'")
    out.printLine("  xeto rv foo -limit 10        // increase limit to 10")
    out.printLine("  xeto rv foo -versions 3.1.x  // match version constraints")
    out.printLine("  xeto rv foo-3.1.x            // convenience for above")
    return 1
  }

  override Int run()
  {
    try
    {
      r := getRepo
      n := name
      c := versions == null ? null : LibDependVersions(versions)
      if (n.contains("-"))
      {
        dash := n.index("-")
        n = name[0..<dash]
        c = LibDependVersions(name[dash+1..-1])
      }
      opts := Etc.dict2x("limit", limit, "versions", c)
      vers := r.versions(n, opts)

      table := Obj[,]
      table.add(["name", "version", "depends"])
      vers.each |x|
      {
        table.add([x.name, x.version.toStr, x.depends.join(", ")])
      }
      Console.cur.table(table)

      ok("Versions success [$r.name, $vers.size versions]")
      return 0
    }
    catch (Err e)
    {
      return err("Versions failed [$getRepoName]", e)
    }
  }
}

**************************************************************************
** RemoteFetchCmd
**************************************************************************

internal class RemoteFetchCmd : RepoRemoteCmd
{
  override Str cmdName() { "remote-fetch" }

  override Str[] aliases() { ["rf"] }

  override Str summary() { "Download lib without installing it" }

  @Arg { help = "Lib name or name-version to query" }
  Str? name

  @Opt { help = "Directory to download to" }
  File? dir

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto remote-fetch foo     // fetch latest version of foo to cwd")
    out.printLine("  xeto rf foo               // using command alias")
    out.printLine("  xeto rf foo-1.2.3         // fetch specific version of foo")
    out.printLine("  xeto rf foo -dir someDir  // fetch to a specific directory")
    return 1
  }

  override Int run()
  {
    try
    {
      r := getRepo

      // get name + version from arguments
      n := name
      v := null
      if (n.contains("-"))
      {
        dash := n.index("-")
        n = name[0..<dash]
        v = Version(name[dash+1..-1])
      }
      else
      {
        v = r.latest(n).version
      }

      // fetch
      buf := r.fetch(n, v)

      // write to file
      fileName := "${n}-${v}.xetolib"
      file := dir == null ? File(fileName.toUri) : dir.uri.plusSlash.plusName(fileName).toFile
      file.out.writeBuf(buf).close

      // print success
      size := file.size.toLocale("B")
      ok("Fetched [$file.osPath, $size]")
      return 0
    }
    catch (Err e)
    {
      return err("Fetch failed [$getRepoName $name]", e)
    }
  }
}

