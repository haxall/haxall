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
** Build: testData
**
class Build : BuildPod
{
  new make()
  {
    podName = "testData"
    summary = "Data processing test suite"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "util @{fan.depend}",
               "yaml @{fan.depend}",
               "data @{hx.depend}",
               "haystack @{hx.depend}",
               "xeto @{hx.depend}",
               "axon @{hx.depend}",
               "hx @{hx.depend}",
               ]
    srcDirs = [`fan/`]
  }
}