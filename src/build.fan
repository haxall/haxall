#! /usr/bin/env fan
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Mar 2021  Brian Frank  Creation

using build
using util

**
** Top level build script
**
class Build : BuildGroup
{
  new make()
  {
    childrenScripts =
    [
      `util/build.fan`,
      `core/build.fan`,
      `lib/build.fan`,
      `conn/build.fan`,
      `tool/build.fan`,
      `test/build.fan`,
      `doc/build.fan`,
    ]
  }

//////////////////////////////////////////////////////////////////////////
// Superclean
//////////////////////////////////////////////////////////////////////////

  @Target { help = "Delete entire lib/ directory" }
  Void superclean()
  {
    Delete(this, Env.cur.workDir + `lib/fan/`).run
  }

//////////////////////////////////////////////////////////////////////////
// Zip
//////////////////////////////////////////////////////////////////////////

  @Target { help = "Create dist zip file" }
  Void zip()
  {
    buildVersion := Version(config("buildVersion"))
    moniker := "haxall-$buildVersion"

    // top level dirs to include
    env := (PathEnv)Env.cur
    if (env.path.size != 3) throw Err("Env must be fantom, haystack-defs, haxall")
    fanDir  := env.path[2]
    hayDir  := env.path[1]
    hxDir   := env.path[0]
    topDirs := [
      // bin
      fanDir + `bin/`,
      hxDir  + `bin/`,
      // lib
      fanDir  + `lib/`,
      hayDir  + `lib/`,
      hxDir   + `lib/`,
      // etc
      fanDir + `etc/build/`,
      fanDir + `etc/sys/`,
      fanDir + `etc/web/`,
    ]

    // create zip-include dir
    includeDir := scriptDir + `../zip-include/`
    includeDir.delete

    // filter for zip task
    filter := |File f, Str path->Bool|
    {
      n := f.name

      // always recurse etc to get more fine grained matches
      if (f.name == "etc") return true

      // skip any files not in our topDir match
      topMatch := topDirs.any |topDir| { f.toStr.startsWith(topDir.toStr) }
      if (!topMatch) return false

      // skip hidden .hg* and .DS_Store files
      if (n.startsWith(".")) return false

      // jar filter - strip swt jars
      if (f.ext == "jar")
      {
        return f.name == "sys.jar"
      }

      // pod filter
      if (f.ext == "pod")
      {
        if (!distPod(f.basename)) return false
      }

      if (f.isDir) log.info("  Adding dir [$f.osPath]")
      return true
    }

    // build path to zip up
    path := ((PathEnv)Env.cur).path.dup
    path.add(includeDir)

    // run it
    zip := CreateZip(this)
    {
      it.outFile    = scriptDir + `../${moniker}.zip`
      it.inDirs     = path
      it.pathPrefix = "$moniker/".toUri
      it.filter     = filter
    }
    zip.run

    // cleanup
    includeDir.delete
  }

  Bool distPod(Str name)
  {
    if (name.startsWith("test")) return false
    if (name == "flux") return false
    if (name == "fluxText") return false
    if (name == "fwt") return false
    if (name == "gfx") return false
    if (name == "icons") return false
    if (name == "webfwt") return false
    return true
  }
}

