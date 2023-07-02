#! /usr/bin/env fan
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 2021  Brian Frank  Creation

using build

**
** Build script for test directory
**
class Build : BuildGroup
{
  new make()
  {
    childrenScripts =
    [
      `testHaystack/build.fan`,
      `testXeto/build.fan`,
      `testAxon/build.fan`,
      `testFolio/build.fan`,
      `testHx/build.fan`,
    ]
  }
}

