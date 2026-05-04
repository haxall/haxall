#! /usr/bin/env fan
//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 May 2026  Trevor Adelman  Creation
//

using build

**
** Build: hxRepo
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxRepo"
    summary = "Xeto remote repo management and installation"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
               "xeto @{hx.depend}",
               "xetom @{hx.depend}",
               "haystack @{hx.depend}",
               "axon @{hx.depend}",
               "hx @{hx.depend}"]
    srcDirs = [`fan/`]
    index   = ["xeto.bindings":"hx.repo"]
  }
}
