#! /usr/bin/env fan
//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using build

**
** Build: xetoGen
**
class Build : BuildPod
{
  new make()
  {
    podName = "xetoGen"
    summary = "Xeto source code generators"
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
               "compiler @{fan.depend}",
               "xeto @{hx.depend}",
               "xetom @{hx.depend}",
               "haystack @{hx.depend}"]
    srcDirs = [`fan/`, `fan/ast/`, `fan/steps/`, `test/`]
    index   = ["xeto.cmd": "xetoGen::GenFanCmd"]
  }
}

