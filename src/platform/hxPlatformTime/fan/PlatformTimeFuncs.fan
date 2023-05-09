//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 May 2023  Brian Frank       Creation
//

using axon
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

  ** Return grid of summary information used to populate UI.
  ** This is a nodoc method subject to change
  @NoDoc @Axon { su = true }
  static Grid platformTimeInfo()
  {
    cx := curContext
    now := DateTime.now
    gb := GridBuilder().addCol("dis").addCol("val").addCol("icon").addCol("edit")
    gb.addRow(["Time", "___", "clock", Marker.val])
    gb.addRow(["Time", now.time.toLocale, null, null])
    gb.addRow(["Date", now.date.toLocale, null, null])
    gb.addRow(["TimeZone", now.tz.name, null, null])
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
    cx.rt.lib("platformTime")
  }
}

