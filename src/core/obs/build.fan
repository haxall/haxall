#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2021  Brian Frank  Creation
//

using build

**
** Build: obs
**
class Build : BuildPod
{
  new make()
  {
    podName = "obs"
    summary = "Observable data stream framework"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "util @{fan.depend}",
               "web @{fan.depend}",
               "haystack @{hx.depend}",
               ]
    srcDirs = [`fan/`]
    resDirs = [`lib/`]

    index =
    [
      "ph.lib": "obs",
    ]
  }
}