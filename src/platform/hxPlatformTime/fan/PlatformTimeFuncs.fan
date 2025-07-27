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
  @Api @Axon { su = true }
  static Void platformTimeSet(DateTime ts)
  {
    ext.platformSpi.timeSet(ts)
  }

  ** Get the list of network time protocol server addresses as
  ** list of strings.  If NTP is not supported, then return null.
  @Api @Axon { su = true }
  static Str[]? platformTimeNtpServersGet()
  {
    ext.platformSpi.ntpServersGet
  }

  ** Set the list of network time protocol server addresses as
  ** list of strings.
  @Api @Axon { su = true }
  static Void platformTimeNtpServersSet(Str[] addresses)
  {
    ext.platformSpi.ntpServersSet(addresses)
  }

  ** Return grid of summary information used to populate UI.
  ** This is a nodoc method subject to change
  @NoDoc @Api @Axon { su = true }
  static Grid platformTimeInfo()
  {
    cx  := curContext
    ext := ext(cx)
    now := DateTime.now
    gb  := GridBuilder().addCol("dis").addCol("val").addCol("icon").addCol("edit")

    gb.addRow(["Time", "___", "clock", "time"])
    gb.addRow(["Time", now.time.toLocale, null, null])
    gb.addRow(["Date", now.date.toLocale, null, null])
    gb.addRow(["TimeZone", now.tz.name, null, null])

    ntp := ext.platformSpi.ntpServersGet
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

  private static Context curContext()
  {
    Context.cur
  }

  private static PlatformTimeExt ext(Context cx := curContext)
  {
    cx.proj.ext("hx.platform.time")
  }
}

