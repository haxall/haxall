#! /usr/bin/env fan
//
// Copyright (c) 2011, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Nov 2011  Brian Frank  Creation
//

using build

**
** Build: hxXml
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxXml"
    summary = "XML function library"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends  = ["sys @{fan.depend}",
                "xml @{fan.depend}",
                "axon @{hx.depend}",
                "haystack @{hx.depend}",
                "hx @{hx.depend}",
               ]
    srcDirs = [`fan/`, `test/`]
    resDirs = [`lib/`]
    index   = ["ph.lib": "xml"]
  }
}