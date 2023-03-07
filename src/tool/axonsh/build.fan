#! /usr/bin/env fan
//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jan 2023  Brian Frank  Creation
//

using build

**
** Build: axonsh
**
class Build : BuildPod
{
  new make()
  {
    podName = "axonsh"
    summary = "Axon shell command line interface"
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
               "data @{hx.depend}",
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "xeto @{hx.depend}"]
    srcDirs = [`fan/`]
  }
}