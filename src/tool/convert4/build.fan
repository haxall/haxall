#! /usr/bin/env fan
//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using build

**
** Build: convert4
**
class Build : BuildPod
{
  new make()
  {
    podName = "convert4"
    summary = "Haxall convert to 4.0 CLI tools"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "fandoc @{fan.depend}",
               "markdown @{fan.depend}",
               "util @{fan.depend}",
               "xeto @{hx.depend}",
               "xetom @{hx.depend}",
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "hxm @{hx.depend}",
               ]
    srcDirs = [`fan/`, `fan/ast/`, `fan/doc/`]
  }
}

