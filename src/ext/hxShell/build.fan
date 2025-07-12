#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jun 2021  Brian Frank  Creation
//

using build

**
** Build: hxShell
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxShell"
    summary = "Axon shell user interface"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "graphics @{fan.depend}",
               "dom @{fan.depend}",
               "domkit @{fan.depend}",
               "web @{fan.depend}",
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "hx @{hx.depend}"]
    srcDirs = [`fan/`, `fan/ui/`]
    resDirs = [`lib/`, `res/css/`]
    docApi  = false
    index   = ["xeto.bindings": "hx.shell", "ph.lib": "hxShell"]
  }
}

