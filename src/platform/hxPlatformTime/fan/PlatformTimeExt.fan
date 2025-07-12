//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 May 2023  Brian Frank  Creation
//

using concurrent
using haystack
using hx

**
** Platform support for date and time
**
const class PlatformTimeExt : Ext
{

  new make()
  {
    this.platformSpi = rt.config.makeSpi("platformTimeSpi")
  }

  internal const PlatformTimeSpi platformSpi

}

