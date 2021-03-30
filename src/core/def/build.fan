#! /usr/bin/env fan
//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Nov 2018  Brian Frank  Creation
//

using build

**
** Build: def
**
class Build : BuildPod
{
  new make()
  {
    podName = "def"
    summary = "Haystack def namespace implementation"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "compilerJs @{fan.depend}",
               "web @{fan.depend}",
               "rdf @{hx.depend}",
               "haystack @{hx.depend}"]
    srcDirs = [`fan/`,
               `fan/rdf/`,
              ]
  }
}