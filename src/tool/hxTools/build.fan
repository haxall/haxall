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
** Build: hxTools
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxTools"
    summary = "Haxall CLI tools"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "crypto @{fan.depend}",
               "util @{fan.depend}",
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               "def @{hx.depend}",
               "folio @{hx.depend}",
               "hx @{hx.depend}",
               "hxm @{hx.depend}",
               "hxd @{hx.depend}",
               "hxFolio @{hx.depend}"]
    srcDirs = [`fan/`]
    resDirs = [`lib/stub/`]
    index =
    [
      "hx.cli": [
        "hxTools::ConvertCli",
        "hxTools::CryptoCli",
        "hxTools::InitCli",
        "hxTools::StubCli",
      ]
    ]
  }
}

