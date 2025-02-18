#! /usr/bin/env fan
//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2023  Brian Frank  Split out from xetoc
//

using build

**
** Build: xeto
**
class Build : BuildPod
{
  new make()
  {
    podName = "xetoEnv"
    summary = "Xeto environment implementation"
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
               "haystack @{hx.depend}"]
  srcDirs = [`fan/ast/`,
             `fan/comp/`,
             `fan/export/`,
             `fan/impl/`,
             `fan/io/`,
             `fan/ns/`,
             `fan/remote/`,
             `fan/util/`,
             ]
  }
}

