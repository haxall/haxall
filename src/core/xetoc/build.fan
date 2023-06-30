#! /usr/bin/env fan
//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2023  Brian Frank  Creation
//

using build

**
** Build: xetoc
**
class Build : BuildPod
{
  new make()
  {
    podName = "xetoc"
    summary = "Xeto compiler and implementation"
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
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               ]
    srcDirs = [`fan/env/`,
               `fan/compiler/`,
               `fan/ast/`,
               `fan/impl/`,
               `fan/util/`,
               ]
  }
}