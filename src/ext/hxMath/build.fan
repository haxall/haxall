#! /usr/bin/env fan
//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Dec 2010   Brian Frank   Creation
//

using build

**
** Build: hxMath
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxMath"
    summary = "Math function libary"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends  = ["sys @{fan.depend}",
                "math @{fan.depend}",
                "util @{fan.depend}",
                "xeto @{hx.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "hx @{hx.depend}"]
    srcDirs = [`fan/`, `test/`]
    resDirs = [`lib/`]
    index   = ["xeto.bindings":"hx.math", "ph.lib": "math"]
  }
}

