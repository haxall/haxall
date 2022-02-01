#! /usr/bin/env fan
//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jan 2022  Matthew Giannini  Creation
//

using build

**
** Build: hxNest
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxNest"
    summary = "Google Nest Connector"
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
                "web @{fan.depend}",
                "util @{fan.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "folio @{hx.depend}",
                "hx @{hx.depend}",
                "hxConn @{hx.depend}",
                "oauth2 @{hx.depend}",
               ]
    srcDirs = [`fan/`,
               `fan/api/`,
               `fan/model/`,
               `fan/task/`,
              ]
    resDirs = [`lib/`]
    index   = ["ph.lib": "nest"]
  }
}