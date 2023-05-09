//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 May 2023  Brian Frank  Creation
//

**
** Platform service provider interface for date and time
**
const mixin PlatformTimeSpi
{
  ** Set the current time
  abstract Void timeSet(DateTime ts)

  ** Get the list of network time protocol server addresses.
  ** If NTP is not supported, then return null.
  abstract Str[]? ntpServersGet()

  ** Set the list of network time protocol server addresses.
  abstract Void ntpServersSet(Str[] addresses)
}