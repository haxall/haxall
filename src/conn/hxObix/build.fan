#! /usr/bin/env fan
//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Feb 2010  Brian Frank  Creation
//

using build

**
** Build: hxObix
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxObix"
    summary = "oBIX Connector"
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
                "inet @{fan.depend}",
                "web @{fan.depend}",
                "xml @{fan.depend}",
                "auth @{hx.depend}",
                "obix @{hx.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "folio @{hx.depend}",
                "hx @{hx.depend}",
                "hxConn @{hx.depend}",
               ]
    srcDirs = [`fan/`, `test/`]
    resDirs = [`lib/`]
    index   = ["ph.lib": "obix"]
  }
}

