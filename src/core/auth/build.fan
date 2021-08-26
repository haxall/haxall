#! /usr/bin/env fan
//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 16  Brian Frank  Creation
//

using build

**
** Build: auth
**
class Build : BuildPod
{
  new make()
  {
    podName = "auth"
    summary = "Authentication framework"
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
               "web @{fan.depend}",
               "haystack @{hx.depend}"]
    srcDirs = [`fan/`,
               `fan/schemes/`,
               `test/`]
    index  =
    [
      "auth.scheme": [
        "auth::BasicScheme",
        "auth::Folio2Scheme",
        "auth::HmacScheme",
        "auth::ScramScheme",
        "auth::PlaintextScheme",
        "auth::XPlaintextScheme",
      ]
    ]
  }

}