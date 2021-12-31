//
// Copyright (c) 2014, SkyFoundry LLC
// All Rights Reserved
//
// History:
//   18 Aug 2014  Brian Frank  Creation
//   31 Dec 2021  Brian Frank  Haxall (last day of 2021)
//

using concurrent
using haystack

**
** ConnTuning models a `connTuning` rec.
** See `lib-conn::doc#tuning`
**
const final class ConnTuning
{
  ** Default empty tuning configuration
  static const ConnTuning defVal := make(Etc.makeDict1("id", Ref("default", "Default")))

  ** Construct with current record
  new make(Dict rec)
  {
    this.configRef = AtomicRef(ConnTuningConfig(rec))
  }

  ** Record id
  Ref id() { config.id }

  ** Rec for tuning config
  Dict rec() { config.rec }

  ** Display name
  Str dis() { config.dis }

  ** Debug string
  override Str toStr() { "ConnTuning [$rec.id.toZinc]" }

  ** Frequency between polls of 'curVal' (default is 10sec).
  ** See `lib-conn::doc#pollTime`.
  Duration pollTime() { config.pollTime }

  ** Time before a point's curStatus marked from "ok" to "stale" (default is 5min)
  ** See `lib-conn::doc#staleTime`.
  Duration staleTime() { config.staleTime }

  ** Minimum time between writes used to throttle the speed of writes
  ** See `lib-conn::doc#writeMinTime`.
  Duration? writeMinTime() { config.writeMinTime }

  ** Maximum time between writes used to send periodic writes
  ** See `lib-conn::doc#writeMaxTime`.
  Duration? writeMaxTime() { config.writeMaxTime }

  ** Rewrite the point everytime time the connector transitions to open
  @NoDoc Bool writeOnOpen() { config.writeOnOpen }

  ** Issue a write when system starts up, otherwise suppress it
  @NoDoc Bool writeOnStart() { config.writeOnStart }

  ** Rec configuration
  internal ConnTuningConfig config() { configRef.val }
  private const AtomicRef configRef

  ** Called when record is modified
  internal Void updateRec(Dict newRec)
  {
    configRef.val = ConnTuningConfig(newRec)
  }
}

**************************************************************************
** ConnTuningConfig
**************************************************************************

** ConnTuningConfig models current state of rec dict
internal const class ConnTuningConfig
{
  new make(Dict rec)
  {
    this.id           = rec.id
    this.rec          = rec
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

  const Ref id
  const Dict rec
  const Str dis
  const Duration pollTime
  const Duration staleTime
  const Duration? writeMinTime
  const Duration? writeMaxTime
  const Bool writeOnOpen
  const Bool writeOnStart
}