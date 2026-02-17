//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   24 Jan 2022  Brian Frank  Redesign for Haxall
//

using xeto
using haystack
using hxPoint

**
** ConnPointWriteState stores and handles all writeVal state
**
internal const final class ConnPointWriteState
{

//////////////////////////////////////////////////////////////////////////
// Transitions
//////////////////////////////////////////////////////////////////////////

  static new updateOk(ConnPoint pt, ConnWriteInfo info)
  {
    makeOk(pt.writeState, info)
  }

  static new updateErr(ConnPoint pt, ConnWriteInfo info, Err err)
  {
    makeErr(pt.writeState, info, err)
  }

  static new updateReceived(ConnPoint pt, ConnWriteInfo lastInfo)
  {
    makeReceived(pt.writeState, lastInfo)
  }

  static new updatePending(ConnPoint pt, Bool pending)
  {
    old := pt.writeState
    if (old.pending == pending) return old
    return makePending(old, pending)
  }

  static new updateQueued(ConnPoint pt, Bool queued)
  {
    old := pt.writeState
    if (old.queued == queued) return old
    return makeQueued(old, queued)
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  Void details(StrBuf s, ConnPoint pt)
  {
    s.add("""writeAddr:        $pt.writeAddr
             writeStatus:      $status
             writeVal:         $val [${val?.typeof}]
             writeRaw:         $raw [${raw?.typeof}]
             writeConvert:     $pt.writeConvert
             writeLastInfo:    $lastInfo
             writePending:     $pending
             writeQueued:      $queued
             writeLastUpdate:  ${Etc.debugDur(lastUpdate)}
             writeNumUpdate:   $numUpdates
             writeErr:         ${Etc.debugErr(err)}
             """)
  }

//////////////////////////////////////////////////////////////////////////
// Constructors
//////////////////////////////////////////////////////////////////////////

  static const ConnPointWriteState nil := makeNil()
  private new makeNil() { status = ConnStatus.unknown }

  private new makeOk(ConnPointWriteState old, ConnWriteInfo info)
  {
    this.status     = ConnStatus.ok
    this.lastUpdate = Duration.nowTicks
    this.numUpdates = old.numUpdates + 1
    this.val        = info.val
    this.raw        = info.raw
    this.level      = info.level
    this.lastInfo   = old.lastInfo
    this.pending    = old.pending
    this.queued     = old.queued
  }

  private new makeErr(ConnPointWriteState old, ConnWriteInfo info, Err err)
  {
    this.status     = ConnStatus.fromErr(err)
    this.lastUpdate = Duration.nowTicks
    this.numUpdates = old.numUpdates + 1
    this.val        = info.val
    this.raw        = info.raw
    this.level      = info.level
    this.err        = err
    this.lastInfo   = old.lastInfo
    this.pending    = old.pending
    this.queued     = old.queued
  }

  private new makeReceived(ConnPointWriteState old, ConnWriteInfo lastInfo)
  {
    this.status     = old.status
    this.lastUpdate = old.lastUpdate
    this.numUpdates = old.numUpdates
    this.val        = old.val
    this.raw        = old.raw
    this.level      = old.level
    this.err        = old.err
    this.lastInfo   = lastInfo
    this.pending    = old.pending
    this.queued     = false
  }

  private new makePending(ConnPointWriteState old, Bool pending)
  {
    this.status     = old.status
    this.lastUpdate = old.lastUpdate
    this.numUpdates = old.numUpdates
    this.val        = old.val
    this.raw        = old.raw
    this.level      = old.level
    this.err        = old.err
    this.lastInfo   = old.lastInfo
    this.pending    = pending
    this.queued     = old.queued
  }

  private new makeQueued(ConnPointWriteState old, Bool queued)
  {
    this.status     = old.status
    this.lastUpdate = old.lastUpdate
    this.numUpdates = old.numUpdates
    this.val        = old.val
    this.raw        = old.raw
    this.level      = old.level
    this.err        = old.err
    this.lastInfo   = old.lastInfo
    this.pending    = old.pending
    this.queued     = queued
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const ConnStatus status
  const Obj? val
  const Obj? raw
  const Int level
  const Err? err
  const Int lastUpdate
  const Int numUpdates
  const ConnWriteInfo? lastInfo
  const Bool pending
  const Bool queued
}


**************************************************************************
** ConnWriteInfo
**************************************************************************

**
** ConnWriteInfo wraps the value to write to the remote system.
** It carries information used to update local transient tags.
**
const class ConnWriteInfo
{
  ** Constructor from a live write observation (onPointWrite callback)
  internal new make(WriteObservation obs)
  {
    this.raw          = obs.val
    this.val          = obs.val
    this.level        = obs.level.toInt
    this.isFirst      = obs.isFirst
    this.isPointWrite = true
    this.who          = obs.who
    this.opts         = obs.opts ?: Etc.dict0
    this.extra        = ""
  }

  ** Conversion constructor
  internal new convert(ConnWriteInfo orig, ConnPoint pt)
  {
    this.raw          = orig.val
    this.val          = pt.writeConvert.convert(pt.ext.pointExt, pt.rec, orig.val)
    this.level        = orig.level
    this.isFirst      = orig.isFirst
    this.isPointWrite = orig.isPointWrite
    this.who          = orig.who
    this.opts         = orig.opts
    this.extra        = orig.extra
  }

  ** Copy with extra message (minTime/maxTime/onOpen housekeeping rewrites)
  internal new makeExtra(ConnWriteInfo orig, Str extra)
  {
    this.raw          = orig.raw
    this.val          = orig.val
    this.level        = orig.level
    this.isFirst      = orig.isFirst
    this.isPointWrite = false
    this.who          = orig.who
    this.opts         = orig.opts
    this.extra        = extra
  }

  ** Value to write to the remote system; might be converted from writeVal
  const Obj? val

  ** Local effective value; used to update writeVal
  @NoDoc const Obj? raw

  ** Local effective level; used to update writeLevel
  @NoDoc const Int level

  ** Is the first write since we booted up
  @NoDoc const Bool isFirst

  ** Is this write a live value from an onPointWrite observation
  ** vs a housekeeping rewrite (minTime, maxTime, or onOpen)
  @NoDoc const Bool isPointWrite

  ** Who made the write
  @NoDoc const Obj? who

  ** Options passed to point write
  @NoDoc const Dict opts

  ** Extra info indicating a special write transition
  @NoDoc const Str extra

  ** Debug string representation
  override Str toStr() { "$val @ $level [$who] $extra" }

  This asMinTime() { makeExtra(this, "minTime") }
  This asMaxTime() { makeExtra(this, "maxTime") }
  This asOnOpen()  { makeExtra(this, "onOpen") }

}

