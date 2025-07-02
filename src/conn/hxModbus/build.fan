#! /usr/bin/env fan
//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jul 2012  Andy Frank        Creation
//  12 Jan 2022  Matthew Giannini  Redesign for Haxall
//

using build

**
** Build: hxModbus
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxModbus"
    summary = "Modbus connector"
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
                "inet @{fan.depend}",
                "util @{fan.depend}",
                "xeto @{hx.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "folio @{hx.depend}",
                "hx @{hx.depend}",
                "hxConn @{hx.depend}",
                "hxPlatformSerial @{hx.depend}",
               ]
    srcDirs = [`fan/`,
               `fan/dev/`,
               `fan/protocol/`,
               // `fan/regMap/`,
               `test/`,
              ]
    resDirs = [`lib/`,]

    index =
    [
      "ph.lib": "modbus",
    ]
  }
}

