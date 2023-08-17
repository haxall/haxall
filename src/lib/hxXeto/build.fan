#! /usr/bin/env fan
//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023  Brian Frank  Creation
//

using build

**
** Build: hxXeto
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxXeto"
    summary = "Xeto data and spec function library"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    depends = ["sys @{fan.depend}",
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "hx @{hx.depend}"]
    srcDirs = [`fan/`]
    resDirs = [`lib/`]
    index   = ["ph.lib": "xeto"]
  }
}