//
// Copyright (c) 2014, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Aug 2014  Brian Frank  Creation
//   31 Dec 2021  Brian Frank  Haxall (last day of 2021)
//

using concurrent
using xeto
using haystack
using obs

**
** ConnTuningRoster manages the configured ConnTuning instances.
**
@NoDoc
const final class ConnTuningRoster
{
  ** List the configured connTuning records
  ConnTuning[] list()
  {
    byId.vals(ConnTuning#)
  }

  ** Lookup a connTuning record by its id
  ConnTuning? get(Ref id, Bool checked := true)
  {
    t := byId.get(id)
    if (t != null) return t
    if (checked) throw UnknownConnTuningErr("Tuning rec not found: $id.toZinc")
    return null
  }

  ** Get tuning for library level or fallback to library specific default
  internal ConnTuning forLib(ConnExt ext)
  {
    forRec(ext.settings) ?: ext.tuningDefault
  }

  ** Get or stub a ConnTuning instance to use for the given
  ** lib, conn, or point record if connTuningRef is configured.
  internal ConnTuning? forRec(Dict rec)
  {
    ref := rec["connTuningRef"] as Ref
    if (ref == null) return null
    return getOrStub(ref)
  }

  ** Get a tuning instance by id.  If not found, then stub a default
  ** version to use for the given id which we might backpatch later.
  ** This design allows us to build out Conn/ConnPoint roster even if this
  ** tuning roster isn't fully loaded yet.  Plus it allows resolution of
  ** ConnTuning instances which might not exist yet (if using cloning)
  private ConnTuning getOrStub(Ref id)
  {
    t := byId.get(id)
    if (t != null) return t
    t = ConnTuning(Etc.dict1("id", id))
    t = byId.getOrAdd(id, t)
    return t
  }

  ** Handle commit event on a connTuning rec
  internal Void onEvent(CommitObservation e)
  {
    if (e.isRemoved)
    {
      byId.remove(e.id)
    }
    else
    {
      cur := byId.get(e.id) as ConnTuning
      if (cur == null)
        byId.getOrAdd(e.id, ConnTuning(e.newRec))
      else
        cur.updateRec(e.newRec)
    }
  }

  private const ConcurrentMap byId := ConcurrentMap()
}

**************************************************************************
** ConnTuning
**************************************************************************

**
** ConnTuning models a `hx.conn::ConnTuning` spec record.
** See `hx.doc.haxall::ConnTuning` chapter
**
const final class ConnTuning
{
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

  ** Frequency between polls of 'curVal'.
  ** See See `hx.doc.haxall::ConnTuning#polltime`.
  Duration pollTime() { config.pollTime }

  ** Time before a point's curStatus marked from "ok" to "stale".
  ** See See `hx.doc.haxall::ConnTuning#staletime`.
  Duration staleTime() { config.staleTime }

  ** Minimum time between writes used to throttle the speed of writes.
  ** See See `hx.doc.haxall::ConnTuning#writemintime`.
  Duration? writeMinTime() { config.writeMinTime }

  ** Maximum time between writes used to send periodic writes.
  ** See See `hx.doc.haxall::ConnTuning#writemaxtime`.
  Duration? writeMaxTime() { config.writeMaxTime }

  ** Rewrite the point everytime time the connector transitions to open.
  ** See See `hx.doc.haxall::ConnTuning#writeonopen`.
  Bool writeOnOpen() { config.writeOnOpen }

  ** Issue a write when system starts up, otherwise suppress it.
  ** See `hx.doc.haxall::ConnTuning#writeonstart`.
  Bool writeOnStart() { config.writeOnStart }

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

