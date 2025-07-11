//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 May 2023  Brian Frank  Creation
//

using concurrent
using haystack
using hx

**
** Platform support for IP network config
**
const class PlatformNetworkLib : Ext
{

  new make()
  {
    this.platformSpi = rt.config.makeSpi("platformNetworkSpi")
  }

  internal const PlatformNetworkSpi platformSpi

}

