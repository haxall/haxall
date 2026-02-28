#! /usr/bin/env fan
//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jan 2016   Brian Frank  Creation
//

using build

**
** Build: testAxon
**
class Build : BuildPod
{
  new make()
  {
    podName = "testAxon"
    summary = "Tests for axon"
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
               "xetom @{hx.depend}",
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "hx @{hx.depend}",
               "testHaystack @{hx.depend}"]
    srcDirs = [`fan/`]
  }
}

