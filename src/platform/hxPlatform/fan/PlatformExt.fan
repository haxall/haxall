//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 May 2023  Brian Frank  Creation
//

using xeto
using hx

**
** Platform support for basic functionality
**
const class PlatformExt : ExtObj, IPlatformExt
{
  new make()
  {
    this.platformSpi = sys.config.makePlatformSpi(this, "platformSpi")
  }

  override Void reboot() { platformSpi.reboot }

  override Void restart() { platformSpi.restart }

  override Void shutdown() { platformSpi.shutdown }

  override Dict[] info() { platformSpi.info }

  internal const PlatformSpi platformSpi

}

