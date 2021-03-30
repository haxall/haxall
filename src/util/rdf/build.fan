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
               "org.uri":      "http://skyfoundry.com/",
               "proj.name":    "SkySpark",
               "license.name": "Commercial",
               "skyspark.doc": "false"]
    depends = ["sys @{fan.depend}",
              ]
    srcDirs = [`fan/`,
               `fan/io/`,
               `test/`,
              ]
  }
}