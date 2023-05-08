//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 May 2023  Brian Frank  Creation
//

using haystack

**
** Platform service provider interface for basic functionality
**
const mixin PlatformSpi
{
  ** Reboot the operating system and runtime process
  abstract Void reboot()

  ** Restart runtime process, but do not reboot operating system
  abstract Void restart()

  ** Shutdown operating system and runtime process
  abstract Void shutdown()

  ** Return additional platform summary information as a list of dicts.
  ** Each dict must have three tags: section, dis, and val.  The supported
  ** section names: sw, hw, os, java.
  abstract Dict[] info()
}