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
** Build: hxPlatformSerial
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxPlatformSerial"
    summary = "Platform support for serial ports"
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
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "hx @{hx.depend}",
              ]
    srcDirs = [`fan/`, `test/`]
    resDirs = [`lib/`]
    index   = ["xeto.bindings":"hx.platform.serial", "ph.lib": "platformSerial"]
  }
}

