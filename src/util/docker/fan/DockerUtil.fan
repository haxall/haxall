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
  static const DateTime unixEpoch := DateTime.fromIso("1970-01-01T00:00:00Z")

  ** Given the number of seconds since the UNIX epoch, get the corresponding
  ** timestamp in the given time zone.
  static DateTime unixSecToTs(Int seconds, TimeZone tz := TimeZone.cur)
  {
    (unixEpoch + Duration.fromStr("${seconds}sec")).toTimeZone(tz)
  }
}
