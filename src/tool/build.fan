#! /usr/bin/env fan
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Mar 2021  Brian Frank  Creation

using build

**
** Build script for util directory
**
class Build : BuildGroup
{
  new make()
  {
    childrenScripts =
    [
      `hxTools/build.fan`,
      `axonsh/build.fan`,
    ]
  }
}

