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
** Build: hxHaystack
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxHaystack"
    summary = "Haystack HTTP API connector"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    depends  = ["sys @{fan.depend}",
                "util @{fan.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "hx @{hx.depend}",
                "hxConn @{hx.depend}"]
    srcDirs = [`fan/`,]
    resDirs = [`lib/`]
    index   = ["ph.lib": "hxHaystack"]
  }
}