#! /usr/bin/env fan
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 May 2023  Brian Frank  Creation

using build

**
** Build script for platform directory
**
class Build : BuildGroup
{
  new make()
  {
    childrenScripts =
    [
      `hxPlatform/build.fan`,
      `hxPlatformSerial/build.fan`,
    ]
  }
}

