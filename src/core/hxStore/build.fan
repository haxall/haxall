#! /usr/bin/env fan
//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Nov 2015  Brian Frank  Creation
//

using build

**
** Build: hxStore
**
class Build : BuildPod
{
  new make()
  {
    podName  = "hxStore"
    summary  = "Folio storage engine"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"
              ]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}"]
    srcDirs  = [`fan/`, `test/`]
    javaDirs = [`java/`]
    docApi   = false
  }
}