#! /usr/bin/env fan
//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Jan 2022  Matthew Giannini  Creation
//

using build

**
** Build: hxMqtt
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxMqtt"
    summary = "MQTT Connector"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    depends  = ["sys @{fan.depend}",
                "concurrent @{fan.depend}",
                "crypto @{fan.depend}",
                "inet @{fan.depend}",
                "mqtt @{hx.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "folio @{hx.depend}",
                "obs @{hx.depend}",
                "hx @{hx.depend}",
                "hxd @{hx.depend}",
                "hxConn @{hx.depend}",
               ]
    srcDirs = [`fan/`]
    resDirs = [`lib/`]
    index   = ["ph.lib": "mqtt"]
  }
}