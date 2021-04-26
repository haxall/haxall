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
** Build: def
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
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "util @{fan.depend}",
               "haystack @{hx.depend}"]
    srcDirs = [`fan/`]

    index =
    [
      "hx.cli": ["hx::HelpCli", "hx::VersionCli"]
    ]
  }
}