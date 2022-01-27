#! /usr/bin/env fan
//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 May 20  Matthew Giannini  Creation
//   27 jan 22  Matthew Giannini  Port to Haxall
//

using build

**
** Build: oauth
**
class Build : BuildPod
{
  new make()
  {
    podName = "oauth2"
    summary = "OAuth 2.0 Library"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "inet @{fan.depend}",
               "web @{fan.depend}",
               "wisp @{fan.depend}",
               "util @{fan.depend}",
              ]
    srcDirs = [`fan/`,
              ]
  }
}