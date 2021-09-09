#! /usr/bin/env fan
//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Sep 2021   Brian Frank   Creation
//

using build

**
** Build: hxCrypto
**
class Build : BuildPod
{
  new make()
  {
    podName = "hxCrypto"
    summary = "Cryptographic certificate and key pair management"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends  = ["sys @{fan.depend}",
                "concurrent @{fan.depend}",
                "crypto @{fan.depend}",
                "inet @{fan.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "hx @{hx.depend}"]
    srcDirs = [`fan/`]
    resDirs = [`lib/`]
    index   = ["ph.lib": "crypto"]
  }
}