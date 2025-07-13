#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021   Brian Frank  Creation
//

using build

**
** Build: testHx
**
class Build : BuildPod
{
  new make()
  {
    podName = "testHx"
    summary = "Tests for Haxall runtime"
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
               "xeto @{hx.depend}",
               "haystack @{hx.depend}",
               "auth @{hx.depend}",
               "axon @{hx.depend}",
               "obs @{hx.depend}",
               "folio @{hx.depend}",
               "hx @{hx.depend}",
               "hxm @{hx.depend}",
               "hxFolio @{hx.depend}",
               "hxConn @{hx.depend}"]
    srcDirs = [`fan/`]
    resDirs = [`lib/`, `lib/connTest/`]
    index =   [ "ph.lib": ["hxTestA", "hxTestB", "connTest"] ]
  }
}

