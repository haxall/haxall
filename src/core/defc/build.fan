#! /usr/bin/env fan
//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Jun 2018  Brian Frank  Creation
//

using build

**
** Build: defc
**
class Build : BuildPod
{
  new make()
  {
    podName = "defc"
    summary = "Haystack def compiler"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "fandoc @{fan.depend}",
               "compilerDoc @{fan.depend}",
               "web @{fan.depend}",
               "util @{fan.depend}",
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               "def @{hx.depend}"]
    srcDirs = [`fan/`,
               `fan/ast/`,
               `fan/doc/`,
               `fan/steps/`,
               `fan/util/`,
               `test/`]
    resDirs = [`res/css/`]
  }
}