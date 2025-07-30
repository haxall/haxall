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
** Build: hxUser
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxUser"
    summary = "Haxall auth and user management library"
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
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               "auth @{hx.depend}",
               "def @{hx.depend}",
               "defc @{hx.depend}",
               "axon @{hx.depend}",
               "folio @{hx.depend}",
               "hx @{hx.depend}",
               "hxm @{hx.depend}"]
    srcDirs = [`fan/`]
    resDirs = [`lib/`, `locale/`, `res/`]
    docApi  = false

    index = ["xeto.bindings": "hx.hxd.user", "ph.lib": "hxUser"]
  }
}

