#! /usr/bin/env fan
//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Aug 2024  Matthew Giannini  Creation
//

using build

**
** Build: hxComps
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxComps"
    summary = "Core Components Library"
    meta    = ["org.name":       "SkyFoundry",
               "org.uri":        "https://skyfoundry.com/",
               "proj.name":      "Haxall",
               "proj.uri":       "https://haxall.io/",
               "license.name":   "Academic Free License 3.0",
               "vcs.name":       "Git",
               "vcs.uri":        "https://github.com/haxall/haxall",
              ]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "hx @{hx.depend}",
               "axon @{hx.depend}",
               "xeto @{hx.depend}",
               "xetom @{hx.depend}",
               "haystack @{hx.depend}",
              ]
    srcDirs = [`fan/`,
               `fan/conversions/`,
               `fan/logic/`,
               `fan/math/`,
               `fan/util/`,
               `fan/vars/`,
               `fan/test/`,
               `fan/timer/`,
               `test/`,
              ]
    index   = [
      "xeto.bindings": "hx.comps hxComps::XetoBindingLoader",
    ]
  }
}

