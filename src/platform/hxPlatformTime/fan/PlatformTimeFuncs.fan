//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 May 2023  Brian Frank  Creation
//

using axon
using xeto
using haystack
using hx

**
** Axon library
**
@NoDoc
const class PlatformTimeFuncs
{
  ** Set the system clock time.  It is recommended to restart after.
  @Axon { su = true }
  static Void platformTimeSet(DateTime ts)
  {
    lib.platformSpi.timeSet(ts)
  }

  ** Get the list of network time protocol server addresses as
  ** list of strings.  If NTP is not supported, then return null.
  @Axon { su = true }
  static Str[]? platformTimeNtpServersGet()
  {
    lib.platformSpi.ntpServersGet
  }

  ** Set the list of network time protocol server addresses as
  ** list of strings.
  @Axon { su = true }
  static Void platformTimeNtpServersSet(Str[] addresses)
  {
    lib.platformSpi.ntpServersSet(addresses)
  }

  ** Return grid of summary information used to populate UI.
  ** This is a nodoc method subject to change
  @NoDoc @Axon { su = true }
  static Grid platformTimeInfo()
  {
    cx := curContext
    lib := lib(cx)
    now := DateTime.now
    gb := GridBuilder().addCol("dis").addCol("val").addCol("icon").addCol("edit")

    gb.addRow(["Time", "___", "clock", "time"])
    gb.addRow(["Time", now.time.toLocale, null, null])
    gb.addRow(["Date", now.date.toLocale, null, null])
    gb.addRow(["TimeZone", now.tz.name, null, null])

    ntp := lib.platformSpi.ntpServersGet
    if (ntp != null)
    {
      gb.addRow(["NTP", "___", "cloud", "ntp"])
      ntp.each |address, i|
      {
        gb.addRow(["Server " + (i+1), address, null, null])
      }
    }

    return gb.toGrid
  }

  private static Dict pi(Str section, Str dis, Str val)
  {
    Etc.dict3("section", section, "dis", dis, "val", val)
  }

  private static HxContext curContext()
  {
    HxContext.curHx
  }

  private static PlatformTimeLib lib(HxContext cx := curContext)
  {
    cx.rt.libsOld.get("platformTime")
  }
}

