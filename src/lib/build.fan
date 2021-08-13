#! /usr/bin/env fan
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 May 2021  Brian Frank  Creation

using build

**
** Build script for lib directory
**
class Build : BuildGroup
{
  new make()
  {
    childrenScripts =
    [
      `hxApi/build.fan`,
      `hxHttp/build.fan`,
      `hxUser/build.fan`,
      `hxMath/build.fan`,
      `hxIO/build.fan`,
      `hxTask/build.fan`,
      `hxPoint/build.fan`,
      `hxConn/build.fan`,
      `hxShell/build.fan`,
      `hxXml/build.fan`,
    ]
  }
}

