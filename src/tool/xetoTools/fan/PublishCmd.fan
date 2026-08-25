//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Aug 2026  Brian Frank  Creation
//

using util
using xeto
using xetom
using xetoc

**
** PublishCmd publishes a xetolib file to a remote repo
**
internal class PublishCmd : RepoRemoteCmd
{
  override Str cmdName() { "publish" }

  override Str summary() { "Publish a xetolib file to remote repo" }

  @Arg { help = "Xetolib zip file or directory of xetolibs to publish" }
  File? file

  @Opt { help = "Report what would be published without publishing" }
  Bool preview

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto publish foo.xetolib           // publish to default repo")
    out.printLine("  xeto publish foo.xetolib -r acme   // publish to repo named 'acme'")
    out.printLine("  xeto publish foo.xetolib -preview  // report without publishing")
    out.printLine("  xeto publish someDir/              // publish whole dir in depends order")
    return 1
  }

  override Int run()
  {
    try
    {
      repo := getRepo

      // load the file, or the whole directory ordered by depends; the
      // load fails fast on a corrupt file before any network traffic
      vers := load
      if (preview)
      {
        vers.each |ver| { ok("Preview [$ver to $repo.name, not published]") }
        return 0
      }

      // one session publishes the whole batch
      s := repo.open
      try
      {
        vers.each |ver|
        {
          pub := s.publish(ver.file)
          ok("Published [$pub.name-$pub.version to $repo.name]")
        }
      }
      finally
      {
        s.close
      }
      return 0
    }
    catch (Err e)
    {
      return err("Publish failed [$getRepoName]", e)
    }
  }

  ** Load the file, or every xetolib in the directory ordered so each
  ** lib publishes after its depends
  private LibVersion[] load()
  {
    if (!file.isDir) return [FileLibVersion.loadZipFile(file)]
    vers := file.list.findAll |f| { f.ext == "xetolib" }.map |f->LibVersion| { FileLibVersion.loadZipFile(f) }
    if (vers.isEmpty) throw Err("No xetolibs in dir: $file.osPath")
    return LibVersion.orderByDepends(vers, true)
  }
}

