#! /usr/bin/env fan
//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jan 2009  Brian Frank  Creation
//

using build

**
** Build: obix
**
class Build : BuildPod
{
  new make()
  {
    podName = "obix"
    summary = "oBIX XML modeling and client and server REST"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys 1.0", "inet 1.0", "web 1.0", "concurrent 1.0", "xml 1.0"]
    srcDirs = [`fan/`, `test/`]
    resDirs = [`res/`]
    docSrc  = true
  }
}