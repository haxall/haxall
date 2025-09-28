#! /usr/bin/env fan
//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Apr 2015  Brian Frank  Break out from proj
//

using build

**
** Build: axon
**
class Build : BuildPod
{
  new make()
  {
    podName = "axon"
    summary = "Axon scripting engine"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               "hx.docFantom": "true",
               ]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "xeto @{hx.depend}",
               "xetom @{hx.depend}",
               "haystack @{hx.depend}"]
    srcDirs = [`fan/`,
               `fan/ast/`,
               `fan/comp/`,
               `fan/lib/`,
               `fan/parser/`,
               `fan/stream/`,
               `fan/template/`,
               ]
    resDirs = [`lib/`]
    index = [
      "xeto.bindings": "axon",
      "ph.lib": "axon",
      "def.compDefLoader": "axon::FuncDefLoader"
    ]
  }

}

