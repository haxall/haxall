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
abstract const class PlatformTimeSpi
{
  ** Parent extension
  PlatformTimeExt ext() { extRef }
  private const PlatformTimeExt? extRef

  ** Set the current date, time, and timezone from DateTime.
  ** A restart is required to bring JVM back into a consistent state.
  abstract Void timeSet(DateTime ts)

  ** Get the list of network time protocol server addresses.
  ** If NTP is not supported, then return null.
  abstract Str[]? ntpServersGet()

  ** Set the list of network time protocol server addresses.
  abstract Void ntpServersSet(Str[] addresses)
}

