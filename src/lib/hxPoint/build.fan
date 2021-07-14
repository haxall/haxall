#! /usr/bin/env fan
//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2012  Brian Frank  Creation
//

using build

**
** Build: hxPoint
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxPoint"
    summary = "Point historization and writable support"
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
                "haystack @{hx.depend}",
                "obs @{hx.depend}",
                "axon @{hx.depend}",
                "folio @{hx.depend}",
                "hx @{hx.depend}",
               ]
    srcDirs = [`fan/`, `test/`]
    resDirs = [`lib/`, `thermistor/`]
    index   = ["ph.lib": "point"]
  }
}