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
** Platform support for basic functionality
**
const class PlatformExt : ExtObj
{

  new make()
  {
    this.platformSpi = sys.config.makeSpi("platformSpi")
  }

  internal const PlatformSpi platformSpi

}

