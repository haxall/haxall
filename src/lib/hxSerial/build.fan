#! /usr/bin/env fan
//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jun 2016  Brian Frank      Creation
//  20 Jan 2022  Matthew Giannini Redesign for Haxall
//

using build

**
** Build: hxSerial
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxSerial"
    summary = "Serial port system module"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Acadmemic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "hx @{hx.depend}",
              ]
    srcDirs = [`fan/`, `test/`]
    resDirs = [`lib/`]
    index   = ["ph.lib": "serial"]
  }
}