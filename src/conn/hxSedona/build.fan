#! /usr/bin/env fan
//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 May 2012  Brian Frank  Creation
//

using build

**
** Build: sedonaExt
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxSedona"
    summary = "Sedona Sox connector"
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
                "sys @{fan.depend}",
                "util @{fan.depend}",
                "web @{fan.depend}",
                "xml @{fan.depend}",
                "sedona 1.2.28",
                "xeto @{hx.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "folio @{hx.depend}",
                "hx @{hx.depend}",
                "hxConn @{hx.depend}",
               ]
    srcDirs = [`fan/`]
    resDirs = [`lib/`]
    index   = ["xeto.bindings":"hx.sedona", "ph.lib": "sedona", "hxSedona.scheme": "hxSedona::DefaultSedonaScheme"]
  }
}

