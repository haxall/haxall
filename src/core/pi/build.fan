#! /usr/bin/env fan
//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2026  Brian Frank  Creation
//

using build

**
** Build: pi
**
class Build : BuildPod
{
  new make()
  {
    podName = "pi"
    summary = "Presentation information types"
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
               "xeto @{hx.depend}"]
    srcDirs = [`fan/`]
    index   = ["xeto.bindings": "pi"]
  }
}

