#! /usr/bin/env fan
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Mar 2021  Brian Frank  Creation

using build

**
** Build script for core directory
**
class Build : BuildGroup
{
  new make()
  {
    childrenScripts =
    [
      `haystack/build.fan`,
      `hxUtil/build.fan`,
      `auth/build.fan`,
      `def/build.fan`,
      `defc/build.fan`,
      `axon/build.fan`,
      `obs/build.fan`,
      `folio/build.fan`,
      `hx/build.fan`,
      `hxStore/build.fan`,
      `hxFolio/build.fan`,
      `hxd/build.fan`,
    ]
  }
}

