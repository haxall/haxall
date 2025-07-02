#! /usr/bin/env fan
//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Jan 2016   Brian Frank  Creation
//

using build

**
** Build: testHaystack
**
class Build : BuildPod
{
  new make()
  {
    podName = "testHaystack"
    summary = "Tests for haystack"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               ]
    srcDirs = [`fan/`]
  }
}

