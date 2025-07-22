#! /usr/bin/env fan
//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2010  Brian Frank  Creation
//

using build

**
** Build: hxIO
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxIO"
    summary = "I/O function library"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends  = ["sys @{fan.depend}",
                "util @{fan.depend}",
                "web @{fan.depend}",
                "axon @{hx.depend}",
                "folio @{hx.depend}",
                "ftp @{hx.depend}",
                "xeto @{hx.depend}",
                "haystack @{hx.depend}",
                "def @{hx.depend}",
                "hx @{hx.depend}",
                "hxUtil @{hx.depend}",
               ]
    srcDirs = [`fan/`, `test/`]
    resDirs = [`lib/`]
    index   = ["xeto.bindings":"hx.io", "ph.lib": "io"]
  }
}

