#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Oct 2021  Matthew Giannini  Creation
//

using build

**
** Build: docker
**
class Build : BuildPod
{
  new make()
  {
    podName = "docker"
    summary = "Docker API client"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "web @{fan.depend}",
               "util @{fan.depend}",
              ]
    srcDirs = [`fan/`,
               `fan/command/`,
               `fan/model/`,
               `fan/orm/`,
               `fan/transport/`,
               `test/`,
              ]
    javaDirs = [`java/`]
  }
}