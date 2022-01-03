#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Mar 2021  Matthew Giannini  Creation
//

using build

**
** Build: mqtt
**
class Build : BuildPod
{
  new make()
  {
    podName = "mqtt"
    summary = "MQTT core library"
    meta    = ["org.name":       "SkyFoundry",
               "org.uri":        "https://skyfoundry.com/",
               "proj.name":      "Haxall",
               "proj.uri":       "https://haxall.io/",
               "license.name":   "Academic Free License 3.0",
               "vcs.name":       "Git",
               "vcs.uri":        "https://github.com/haxall/haxall",
              ]
    depends  = ["sys @{fan.depend}",
                "concurrent @{fan.depend}",
                "crypto @{fan.depend}",
                "inet @{fan.depend}",
                "web @{fan.depend}",
                "util @{fan.depend}",
               ]
    srcDirs = [`fan/`,
               `fan/client/`,
               `fan/client/handler/`,
               `fan/client/persist/`,
               `fan/packet/`,
               `test/`,
              ]
  }
}