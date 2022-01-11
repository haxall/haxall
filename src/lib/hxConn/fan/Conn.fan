//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using folio
using hx

**
** Conn models a connection to a single endpoint.
**
const final class Conn : Actor, HxConn
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Internal constructor
  internal new make(ConnLib lib, Dict rec) : super(lib.connActorPool)
  {
    this.libRef    = lib
    this.idRef     = rec.id
    this.configRef = AtomicRef(ConnConfig(lib, rec))
    this.traceRef  = ConnTrace(lib.rt.libs.actorPool)
    sendLater(houseKeepingFreq, houseKeepingMsg)
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Runtime system
  HxRuntime rt() { libRef.rt }

  ** Runtime database
  Folio db() { libRef.rt.db }

  ** Parent connector library
  override ConnLib lib() { libRef }
  private const ConnLib libRef

  ** Record id
  override Ref id() { idRef }
  private const Ref idRef

  ** Debug tracing for this connector
  ConnTrace trace() { traceRef }
  private const ConnTrace traceRef

  ** Log for this connector
  Log log() { libRef.log }

  ** Debug string
  override Str toStr() { "Conn [$id.toZinc]" }

  ** Display name
  Str dis() { config.dis }

  ** Current version of the record.
  ** This dict only represents the current persistent tags.
  ** It does not track transient changes such as 'connStatus'.
  override Dict rec() { config.rec }

  ** Timeout to use for I/O and actor messaging - see `actorTimeout`.
  Duration timeout() { config.timeout }

  ** Frequency to retry opens. See `connOpenRetryFreq`.
  Duration openRetryFreq() { config.openRetryFreq }

  ** Configured ping frequency to test connection or
  ** null if feature is disabled - see `connPingFreq`
  Duration? pingFreq() { config.pingFreq }

  ** Configured linger timeout - see `connLinger`
  Duration linger() { config.linger }

  ** Conn tuning configuration to use for this connector.
  ConnTuning tuning() { config.tuning ?: lib.tuning }

  ** Conn rec configuration
  internal ConnConfig config() { configRef.val }
  private const AtomicRef configRef

//////////////////////////////////////////////////////////////////////////
// Points
//////////////////////////////////////////////////////////////////////////

  ** Get list of all points managed by this connector.
  ConnPoint[] points() { pointsList.val }

  ** Get the point managed by this connector via its point rec id.
  ConnPoint? point(Ref id, Bool checked := true)
  {
    pt := lib.roster.point(id, false) as ConnPoint
    if (pt != null && pt.conn === this) return pt
    if (checked) throw UnknownConnPointErr("Connector point not found: $id.toZinc")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  ** Sync a synchronous message to the actor, and block
  ** based on the configurable timeout.
  Obj? sendSync(HxMsg msg) { send(msg).get(timeout) }

  ** Invoke ping request
  override Future ping() { send(HxMsg("ping")) }

  ** Force close of connection if open
  override Future close() { send(HxMsg("close")) }

  ** Block until this conn processes its current actor queue
  This sync(Duration? timeout := null)
  {
    send(HxMsg("sync")).get(timeout)
    return this
  }

  ** Invoke the learn request
  @NoDoc override Future learnAsync(Obj? arg := null) { send(HxMsg("learn", arg)) }

  ** Actor messages are routed to `ConnDispatch`
  override Obj? receive(Obj? m)
  {
    msg := (HxMsg)m
    state := Actor.locals["s"] as ConnState
    if (state == null)
    {
      try
      {
        Actor.locals["s"] = state = ConnState(this, lib.model.dispatchType)
      }
      catch (Err e)
      {
        log.err("Cannot initialize  ${lib.model.dispatchType}", e)
        throw e
      }
    }

    if (msg === houseKeepingMsg)
    {
      trace.write("hk", "houseKeeping", msg)
      try
        state.onHouseKeeping
      catch (Err e)
        log.err("Conn.receive", e)
      if (isAlive)
        sendLater(houseKeepingFreq, houseKeepingMsg)
      return null
    }

    try
    {
      trace.dispatch(msg)
      return state.onReceive(msg)
    }
    catch (Err e)
    {
      log.err("Conn.receive $msg.id", e)
      throw e
    }
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Return true is connector active or false is it has been removed.
  @NoDoc Bool isAlive() { aliveRef.val }

  ** Set alive state to false
  internal Void kill() { aliveRef.val = false }

  ** Called when record is modified
  internal Void updateRec(Dict newRec)
  {
    configRef.val = ConnConfig(lib, newRec)
  }

  ** Update the points list.
  ** Must pass mutable list which is sorted by this method.
  internal Void updatePointsList(ConnPoint[] pts)
  {
    pointsList.val = pts.sort |a, b| { a.dis <=> b.dis }.toImmutable
  }

  ** Debug details
  @NoDoc override Str details()
  {
    s := StrBuf()
    s.add("""id:            $id
             dis:           $dis
             timeout:       $timeout
             openRetryFreq: $openRetryFreq
             pingFreq:      $pingFreq
             linger:        $linger
             tuning:        $tuning.rec.id.toZinc
             tracing:       $trace.isEnabled
             """)
      return s.toStr
    }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const static Duration houseKeepingFreq := 3sec
  private const static HxMsg houseKeepingMsg := HxMsg("houseKeeping")

  private const AtomicBool aliveRef := AtomicBool(true)
  private const AtomicRef pointsList := AtomicRef(ConnPoint#.emptyList)
}

**************************************************************************
** ConnConfig
**************************************************************************

** ConnConfig models current state of rec dict
internal const final class ConnConfig
{
  new make(ConnLib lib, Dict rec)
  {
    this.rec           = rec
    this.dis           = rec.dis
    this.disabled      = rec.has("disabled")
    this.timeout       = Etc.dictGetDuration(rec, "actorTimeout", 1min).max(1sec)
    this.openRetryFreq = Etc.dictGetDuration(rec, "connOpenRetryFreq", 10sec).max(1sec)
    this.pingFreq      = Etc.dictGetDuration(rec, "connPingFreq")?.max(1sec)
    this.linger        = Etc.dictGetDuration(rec, "connLinger", 30sec).max(0sec)
    this.tuning        = lib.tunings.forRec(rec)
  }

  const Dict rec
  const Str dis
  const Bool disabled
  const Duration timeout
  const Duration openRetryFreq
  const Duration? pingFreq
  const Duration linger
  const ConnTuning? tuning
}

