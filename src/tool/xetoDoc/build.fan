#! /usr/bin/env fan
//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using build

**
** Build: xetoDoc
**
class Build : BuildPod
{
  new make()
  {
    podName = "xetoDoc"
    summary = "Xeto documentation compiler"
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
               "markdown @{fan.depend}",
               "web @{fan.depend}",
               "xeto @{hx.depend}",
               "xetoEnv @{hx.depend}",
               "haystack @{hx.depend}"]
    srcDirs = [`fan/ast/`,
               `fan/compiler/`]
  }
}

