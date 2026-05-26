#! /usr/bin/env fan
//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 May 2026  Matthew Giannini  Creation
//

using build

**
** Build: hxFile
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxFile"
    summary = "Haxall file management and access"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "web @{fan.depend}",
               "util @{fan.depend}",
               "haystack @{hx.depend}",
               "xeto @{hx.depend}",
               "axon @{hx.depend}",
               "hx @{hx.depend}",
               "folio @{hx.depend}",
              ]
    srcDirs = [`fan/`,
               `fan/mounts/`,
              ]
    resDirs = [`lib/`,]
    index   = ["xeto.bindings":"hx.file"]
  }
}