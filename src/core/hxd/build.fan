#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using build

**
** Build: hxd
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxd"
    summary = "Haxall runtime daemon"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "inet @{fan.depend}",
               "util @{fan.depend}",
               "web @{fan.depend}",
               "wisp @{fan.depend}",
               "haystack @{hx.depend}",
               "auth @{hx.depend}",
               "def @{hx.depend}",
               "defc @{hx.depend}",
               "axon @{hx.depend}",
               "folio @{hx.depend}",
               "hx @{hx.depend}",
               "hxFolio @{hx.depend}"]
    srcDirs = [`fan/`, `fan/libs/`]
    resDirs = [`lib/hxdApi/`, `lib/hxdHttp/`, `lib/hxdUser/`]
    docApi  = false

    index =
    [
      "ph.lib": ["hxdApi", "hxdHttp", "hxdUser"],
      "hx.cli": ["hxd::RunCli"]
    ]
  }
}