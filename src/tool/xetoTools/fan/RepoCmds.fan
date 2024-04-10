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
  override Str name() { "repo" }

  override Str summary() { "List locally installed libs" }

  @Opt { help = "List all the installed versions"; aliases=["v"] }
  Bool versions

  @Opt { help = "Full listing including file and dependencies"; aliases=["f"] }
  Bool full

  @Arg { help = "Specific lib name or names to dump" }
  Str[]? libs

  override Int run()
  {
    // find libs to list
    repo := LibRepo.cur
    libNames := this.libs ?: repo.libs
    echo

    // dump each lib
    libNames.each |libName|
    {
      listLib(repo, libName)
    }

    echo
    return 0
  }

  private Void listLib(LibRepo repo, Str name)
  {
    // if not dumping all versions, just print latest
    if (!versions)
    {
      latest := repo.latest(name)
      echo("$name [$latest.version]")
      if (full) listFull(latest, Str.spaces(2))
      return
    }

    // list all of them
    versions := repo.versions(name)
    echo
    echo("$name")
    versions.each |v|
    {
      echo("  $v.version")
      if (full) listFull(v, Str.spaces(4))
    }
  }

  private Void listFull(LibVersion v, Str indent)
  {
    echo(indent + "File: $v.file.osPath")
    v.depends.each |d| { echo(indent + "Depend: $d" ) }
  }
}

