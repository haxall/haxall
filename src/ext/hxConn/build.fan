#! /usr/bin/env fan
//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Nov 2010  Brian Frank  Creation
//

using build

**
** Build: hxConn
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxConn"
    summary = "Haxall connector framework"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               "hx.docFantom": "true",
               ]
    depends  = ["sys @{fan.depend}",
                "concurrent @{fan.depend}",
                "inet @{fan.depend}",
                "xeto @{hx.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "obs @{hx.depend}",
                "folio @{hx.depend}",
                "hx @{hx.depend}",
                "hxUtil @{hx.depend}",
                "hxPoint @{hx.depend}"]
    srcDirs = [`fan/`]
    resDirs = [`lib/`]
    index   = ["xeto.bindings":"hx.conn", "ph.lib": "conn"]
  }
}

