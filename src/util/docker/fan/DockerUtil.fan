//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Oct 2021  Matthew Giannini  Creation
//

**
** Docker utilities
**
const mixin DockerUtil
{
  ** Given the number of seconds since the UNIX epoch, get the corresponding
  ** timestamp in the given time zone.
  static DateTime unixSecToTs(Int seconds, TimeZone tz := TimeZone.cur)
  {
    DateTime.fromJava(seconds * 1000, tz)
  }
}
