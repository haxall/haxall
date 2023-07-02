#! /usr/bin/env fan
//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using build

**
** Build: testXeto
**
class Build : BuildPod
{
  new make()
  {
    podName = "testXeto"
    summary = "Xeto test suite"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "graphics @{fan.depend}",
               "util @{fan.depend}",
               "yaml @{fan.depend}",
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "folio @{hx.depend}",
               "hx @{hx.depend}",
               ]
    srcDirs = [`fan/`]
  }
}
