#! /usr/bin/env fan
//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2019  Matthew Giannini  Creation
//

using build

**
** Build: rdf
**
class Build : BuildPod
{
  new make()
  {
    podName = "rdf"
    summary = "Resource Description Framework (RDF)"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall"]
    depends = ["sys @{fan.depend}",
              ]
    srcDirs = [`fan/`,
               `fan/io/`,
               `test/`,
              ]
  }
}