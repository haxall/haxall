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
using hxPoint

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
    this.libRef      = lib
    this.idRef       = rec.id
    this.configRef   = AtomicRef(ConnConfig(lib, rec))
    this.traceRef    = ConnTrace(lib.rt.libs.actorPool)
    this.pollModeRef = lib.model.pollMode
  }

  internal Void start()
  {
    send(HxMsg("init"))
    sendLater(Conn.houseKeepingFreq, Conn.houseKeepingMsg)
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

  ** PointLib library
  @NoDoc PointLib pointLib() { libRef.pointLib }

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

  ** Does the record have the 'disabled' marker configured
  Bool isDisabled() { config.isDisabled }

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

  ** Current status of the connector
  ConnStatus status() { vars.status }

  ** Current connection open/close state
  @NoDoc ConnState state() { vars.state }

  ** Conn rec configuration
  internal ConnConfig config() { configRef.val }
  private const AtomicRef configRef
  internal Void setConfig(ConnMgr mgr, ConnConfig c) { configRef.val = c }

  ** Mutable variables managed by ConnMgr within actor thread
  internal const ConnVars vars := ConnVars()

  ** Manages all status commits to this record
  internal const ConnCommitter committer := ConnCommitter()

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
// Polling
//////////////////////////////////////////////////////////////////////////

  ** Poll strategy for connector
  ConnPollMode pollMode() { pollModeRef }
  private const ConnPollMode pollModeRef

  ** Configured poll frequency if connector uses manual polling
  Duration? pollFreq() { config.pollFreq }

  ** Effective frequency for ConnPoller based on pollMode and pollFreq
  internal Int pollFreqEffective()
  {
    if (isDisabled) return 0
    if (pollMode === ConnPollMode.buckets) return 100ms.ticks
    if (pollMode === ConnPollMode.manual && pollFreq != null) return pollFreq.ticks
    return 0
  }

  ** Singleton message for poll dispatch
  internal const static HxMsg pollMsg := HxMsg("poll")

  ** Next poll deadline in duration ticks - managed by ConnPoller
  internal const AtomicInt pollNext := AtomicInt(0)

  ** Configured polling buckets if pollMode is buckets
  @NoDoc ConnPollBucket[] pollBuckets() { pollBucketsRef.val }
  private const AtomicRef pollBucketsRef := AtomicRef(ConnPollBucket#.emptyList)
  internal Void setPollBuckets(ConnMgr mgr, ConnPollBucket[] b) { pollBucketsRef.val = b }

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

  ** Synchronize the current values for the given points
  Future syncCur(ConnPoint[] points) { send(HxMsg("syncCur", points)) }

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
    mgr := Actor.locals["mgr"] as ConnMgr
    if (mgr == null)
    {
      try
      {
        Actor.locals["mgr"] = mgr = ConnMgr(this, lib.model.dispatchType)
      }
      catch (Err e)
      {
        log.err("Cannot initialize  ${lib.model.dispatchType}", e)
        throw e
      }
    }

    if (msg === pollMsg)
    {
      try
        mgr.onPoll
      catch (Err e)
        log.err("Conn.receive poll", e)
      return null
    }

    if (msg === houseKeepingMsg)
    {
      trace.write("hk", "houseKeeping", msg)
      try
        mgr.onHouseKeeping
      catch (Err e)
        log.err("Conn.receive houseKeeping", e)
      if (isAlive)
        sendLater(houseKeepingFreq, houseKeepingMsg)
      return null
    }

    try
    {
      trace.dispatch(msg)
      return mgr.onReceive(msg)
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

  ** Update the points list (called on roster threads) .
  ** Must pass mutable list which is sorted by this method.
  internal Void updatePointsList(ConnPoint[] pts)
  {
    pointsList.val = pts.sort |a, b| { a.dis <=> b.dis }.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Debug details
  @NoDoc override Str details()
  {
    s := StrBuf()
    s.add("""id:             $id
             dis:            $dis
             rt:             $rt.platform.hostModel [$rt.version]
             lib:            $lib.typeof [$lib.typeof.pod.version]
             timeout:        $timeout
             openRetryFreq:  $openRetryFreq
             pingFreq:       $pingFreq
             linger:         $linger
             tuning:         $tuning.rec.id.toZinc
             numPoints:      $points.size
             pollMode:       $pollMode
             """)

    switch (pollMode)
    {
      case ConnPollMode.manual:  detailsPollManual(s)
      case ConnPollMode.buckets: detailsPollBuckets(s)
    }

    s.add("\n")
    vars.details(s)

    s.add("\n")
    committer.details(s)

    return s.toStr
  }

  private Void detailsPollManual(StrBuf s)
  {
    s.add("pollFreq:       $pollFreq\n")
  }

  private Void detailsPollBuckets(StrBuf s)
  {
    s.add("pollBuckets:\n")
    pollBuckets.each |b| { s.add("  ").add(b).add("\n") }
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
    model := lib.model

    this.rec           = rec
    this.dis           = rec.dis
    this.isDisabled    = rec.has("disabled")
    this.timeout       = Etc.dictGetDuration(rec, "actorTimeout", 1min).max(1sec)
    this.openRetryFreq = Etc.dictGetDuration(rec, "connOpenRetryFreq", 10sec).max(1sec)
    this.pingFreq      = Etc.dictGetDuration(rec, "connPingFreq", null)?.max(1sec)
    this.linger        = Etc.dictGetDuration(rec, "connLinger", 30sec).max(0sec)
    this.tuning        = lib.tunings.forRec(rec)
    if (model.pollFreqTag != null)
      this.pollFreq = Etc.dictGetDuration(rec, model.pollFreqTag, model.pollFreqDefault).max(100ms)
  }

  const Dict rec
  const Str dis
  const Bool isDisabled
  const Duration timeout
  const Duration openRetryFreq
  const Duration? pingFreq
  const Duration linger
  const Duration? pollFreq
  const ConnTuning? tuning
}

