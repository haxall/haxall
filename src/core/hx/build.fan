#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 2021  Brian Frank  Creation
//

using build

**
** Build: hx
**
class Build : BuildPod
{
  new make()
  {
    podName = "hx"
    summary = "Haxall framework APIs"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               "hx.docFantom": "true",
               ]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "inet @{fan.depend}",
               "crypto @{fan.depend}",
               "util @{fan.depend}",
               "web @{fan.depend}",
               "data @{hx.depend}",
               "haystack @{hx.depend}",
               "def @{hx.depend}",
               "axon @{hx.depend}",
               "obs @{hx.depend}",
               "folio @{hx.depend}"]
    srcDirs = [`fan/`]
    resDirs = [`lib/`]

    index =
    [
      "ph.lib": "hx",
      "hx.cli": ["hx::HelpCli", "hx::VersionCli"]
    ]
  }
}