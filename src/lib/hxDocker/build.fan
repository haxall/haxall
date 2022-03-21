#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Oct 2021  Matthew Giannini
//

using build

**
** Build: hxDocker
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxDocker"
    summary = "Docker management"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    depends  = ["sys @{fan.depend}",
                "concurrent @{fan.depend}",
                "inet @{fan.depend}",
                "util @{fan.depend}",
                "haystack @{hx.depend}",
                "hx @{hx.depend}",
                "axon @{hx.depend}",
                "docker @{hx.depend}",
               ]
    srcDirs = [`fan/`, `fan/model/`]
    resDirs = [`lib/`]
    index   = ["ph.lib": "docker"]
  }
}