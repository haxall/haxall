#! /usr/bin/env fan
//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 May 2023  Brian Frank  Creation
//

using build

**
** Build: hxPlatform
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxPlatform"
    summary = "Platform support for basic functionality"
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
    srcDirs = [`fan/`]
    resDirs = [`lib/`]
    index   = ["xeto.bindings":"hx.platform", "ph.lib": "platform"]
  }
}

