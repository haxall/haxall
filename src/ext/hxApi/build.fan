#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 May 2021  Brian Frank  Creation
//

using build

**
** Build: hxApi
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxApi"
    summary = "Haxall Haystack HTTP API library"
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
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "folio @{hx.depend}",
               "hx @{hx.depend}"]
    srcDirs = [`fan/`]
    resDirs = [`lib/`]
    docApi  = false
    index   = ["xeto.bindings":"hx.api", "ph.lib": "hxApi"]
  }
}

