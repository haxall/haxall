#! /usr/bin/env fan
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Aug 2021  Brian Frank  Creation

using build

**
** Build doc pods
**
class Build : BuildGroup
{
  new make()
  {
    childrenScripts =
    [
      `docHaxall/build.fan`,
    ]
  }
}

