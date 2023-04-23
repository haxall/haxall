//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2023  Brian Frank  Creation
//

using util
using data
using xeto

**
** BuildCmd is used to create xetolib zips
**
internal class BuildCmd : XetoCmd
{
  @Arg { help = "Libs to build or \"all\" to rebuild all source libs" }
  Str[]? libs

  override Str name() { "build" }

  override Str summary() { "Compile xeto source to xetolib" }

  override Int run()
  {
    libs := toSrcLibs(this.libs)
    if (libs == null) return 1
    return env.registry.build(libs)
  }
}

**************************************************************************
** Clean
**************************************************************************

**
** CleanCmd deletes xetolib zips if the lib is a source
**
internal class CleanCmd : XetoCmd
{
  @Arg { help = "Libs to clean or \"all\" to clean all source libs" }
  Str[]? libs

  override Str name() { "clean" }

  override Str summary() { "Delete xetolib files for source libs" }

  override Int run()
  {
    libs := toSrcLibs(this.libs)
    if (libs == null) return 1

    libs.each |lib|
    {
      if (!lib.zip.exists) return
      echo("Delete [$lib.zip]")
      lib.zip.delete
    }
    return 0
  }
}

