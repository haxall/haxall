#! /usr/bin/env fan
//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Dec 2010  Brian Frank  Creation
//

using build

**
** Build: ftp
**
class Build : BuildPod
{
  new make()
  {
    podName = "ftp"
    summary = "FTP client"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}", "inet @{fan.depend}"]
    srcDirs = [`fan/`]
    javaDirs = [`java/`]
    docApi  = false
  }
}