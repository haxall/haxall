#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jul 2021  Brian Frank  Creation
//

using build

**
** Build: hxUtil
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxUtil"
    summary = "Haxall utillity APIs"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    depends = ["sys @{fan.depend}",
               "crypto @{fan.depend}",
               "util @{fan.depend}",
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               ]
    srcDirs = [`fan/`, `test/`]
  }
}

