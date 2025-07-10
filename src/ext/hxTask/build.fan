#! /usr/bin/env fan
//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Apr 2020  Brian Frank  COVID-19!
//

using build

**
** Build: hxTask
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxTask"
    summary = "Async task engine"
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
                "xeto @{hx.depend}",
                "haystack @{hx.depend}",
                "obs @{hx.depend}",
                "axon @{hx.depend}",
                "folio @{hx.depend}",
                "hx @{hx.depend}",
               ]
    srcDirs = [`fan/`, `test/`]
    resDirs = [`lib/`]
    index   = ["ph.lib": "task"]
  }
}

