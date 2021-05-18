#! /usr/bin/env fan
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Mar 2021  Brian Frank  Creation

using build

**
** Top level build script
**
class Build : BuildGroup
{
  new make()
  {
    childrenScripts =
    [
      `util/build.fan`,
      `core/build.fan`,
      `tool/build.fan`,
      `test/build.fan`,
    ]
  }

  @Target { help = "Delete entire lib/ directory" }
  Void superclean()
  {
    Delete(this, Env.cur.workDir + `lib/`).run
  }
}

