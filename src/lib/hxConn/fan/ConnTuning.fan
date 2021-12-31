//
// Copyright (c) 2014, SkyFoundry LLC
// All Rights Reserved
//
// History:
//   18 Aug 2014  Brian Frank  Creation
//   31 Dec 2021  Brian Frank  Haxall (last day of 2021)
//

using haystack

**
** ConnTuning models a `connTuning` rec.
** See `lib-conn::doc#tuning`
**
const class ConnTuning
{
  ** Default empty tuning configuration
  static const ConnTuning defVal := make(Etc.emptyDict)

  ** Construct with current record
  new make(Dict rec)
  {
    this.rec          = rec
    this.id           = rec["id"] ?: Ref("default", "Default")
    this.dis          = id.dis
    this.pollTime     = toDuration("pollTime", 10sec)
    this.staleTime    = toDuration("staleTime", 5min)
    this.writeMinTime = toDuration("writeMinTime", null)
    this.writeMaxTime = toDuration("writeMaxTime", null)
    this.writeOnStart = rec.has("writeOnStart")
    this.writeOnOpen  = rec.has("writeOnOpen")
  }

  private Duration? toDuration(Str tag, Duration? def)
  {
    num := rec[tag] as Number
    if (num == null) return def
    try
    {
      dur := num.toDuration
      if (dur < 10ms) dur = 10ms
      return dur
    }
    catch return def
  }

  ** Rec for tuning config or empty dict if default
  const Dict rec

  ** Display name
  const Str dis

  ** Rec id
  const Ref id

  ** Debug string
  override Str toStr() { "ConnTuning [$id.toZinc]" }

  ** Frequency between polls of 'curVal' (default is 10sec).
  ** See `lib-conn::doc#pollTime`.
  const Duration pollTime

  ** Time before a point's curStatus marked from "ok" to "stale" (default is 5min)
  ** See `lib-conn::doc#staleTime`.
  const Duration staleTime

  ** Minimum time between writes used to throttle the speed of writes
  ** See `lib-conn::doc#writeMinTime`.
  const Duration? writeMinTime

  ** Maximum time between writes used to send periodic writes
  ** See `lib-conn::doc#writeMaxTime`.
  const Duration? writeMaxTime

  ** Rewrite the point everytime time the connector transitions to open
  @NoDoc const Bool writeOnOpen

  ** Issue a write when system starts up, otherwise suppress it
  @NoDoc const Bool writeOnStart
}