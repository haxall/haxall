#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jul 2021  Matthew Giannini  Creation
//

using build

**
** Build: hxPy
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxPy"
    summary = "Python IPC"
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
                "math @{fan.depend}",
                "inet @{fan.depend}",
                "util @{fan.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "hx @{hx.depend}",
               ]
    srcDirs = [`fan/`,
              ]
    resDirs = [`lib/`]
    index   = ["ph.lib": "py"]
  }
}