#! /usr/bin/env fan
//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2012  Brian Frank  Creation
//

using build

**
** Build: sedona (wraps Java jar)
**
class Build : BuildPod
{
  new make()
  {
    podName = "sedona"
    summary = "Sedona Sox Client"
    meta    = ["org.name":     "Sedona",
               "org.uri":      "http://sedonadev.org/",
               "proj.name":    "Sedona",
               "license.name": "Academic Free License 3.0"]
    version = Version("1.2.28.2")
    resDirs = [`sedona.jar`]
    docApi  = false
  }

}