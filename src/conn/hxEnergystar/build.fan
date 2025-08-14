#! /usr/bin/env fan
//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2013  Brian Frank       Creation
//   05 Aug 2025  Matthew Giannini  Refactor for hxConn
//   14 Aug 2025  Brian Frank       Open source for 4.0
//

using build

**
** Build: hxEnergyStar
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxEnergystar"
    summary = "EnergyStar Portfolio Manager connector"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
              ]
    depends  = ["sys @{fan.depend}",
                "dom @{fan.depend}",
                "sys @{fan.depend}",
                "web @{fan.depend}",
                "xml @{fan.depend}",
                "auth @{hx.depend}",
                "xeto @{hx.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "hx @{hx.depend}",
                "hxConn @{hx.depend}",
                "folio @{hx.depend}",
               ]
    srcDirs = [`fan/`,]
    resDirs = [`lib/`]
    docApi  = true
    index = ["xeto.bindings":"hx.energystar", "ph.lib":"energyStar"]
  }
}

