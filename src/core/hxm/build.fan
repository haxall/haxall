#! /usr/bin/env fan
//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using build

**
** Build: hxm
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxm"
    summary = "Haxall runtime implementation"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "xeto @{hx.depend}",
               "xetoc @{hx.depend}",
               "haystack @{hx.depend}",
               "obs @{hx.depend}",
               "folio @{hx.depend}",
               "hx @{hx.depend}",
               "hx4 @{hx.depend}"]
    srcDirs = [`fan/`]
    docApi  = false
    index   = ["xeto.bindings": "hx"]
  }
}

