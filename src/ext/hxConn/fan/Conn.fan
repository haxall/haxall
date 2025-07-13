//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using xeto
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
  internal new make(ConnExt ext, Dict rec)
    : super.makeCoalescing(ext.connActorPool, toCoalesceKey, toCoalesce)
  {
    this.extRef      = ext
    this.idRef       = rec.id
    this.configRef   = AtomicRef(ConnConfig(ext, rec))
    this.traceRef    = ConnTrace(ext.proj.exts.actorPool)
    this.pollModeRef = ext.model.pollMode
  }

  internal Void start()
  {
    send(HxMsg("init"))
    sendLater(Conn.houseKeepingFreq, Conn.houseKeepingMsg)
  }

  private const static |HxMsg msg->Obj?| toCoalesceKey := |HxMsg msg->Obj?|
  {
    // we coalesce write messages per point id
    if (msg.id === "write") return ((ConnPoint)msg.a).id
    // we coalesce poll messages
    if (msg.id === "poll")  return msg.id
    return null
  }

  private const static |HxMsg a, HxMsg b->HxMsg| toCoalesce := |HxMsg a, HxMsg b->HxMsg|
  {
    // last write wins, previous queued up writes are discarded
    return b
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Project
  Proj proj() { extRef.proj }

  ** Project database
  Folio db() { extRef.proj.db }

  ** Parent connector library
  override ConnExt ext() { extRef }
  private const ConnExt extRef

  ** PointExt
  @NoDoc PointExt pointExt() { extRef.pointExt }

  ** Record id
  override Ref id() { idRef }
  private const Ref idRef

  ** Debug tracing for this connector
  ConnTrace trace() { traceRef }
  private const ConnTrace traceRef

  ** Log for this connector
  Log log() { extRef.log }

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
  ConnTuning tuning() { config.tuning ?: ext.tuning }

  ** Library specific connector data.  This value is managed by the
  ** connector actor via `ConnDispatch.setConnData`.
  Obj? data() { dataRef.val }
  private const AtomicRef dataRef := AtomicRef()
  internal Void setData(ConnMgr mgr, Obj? val) { dataRef.val = val }

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
    pt := ext.roster.point(id, false) as ConnPoint
    if (pt != null && pt.conn === this) return pt
    if (checked) throw UnknownConnPointErr("Connector point not found: $id.toZinc")
    return null
  }

  ** Get list of all point ids managed by this connector.
  Ref[] pointIds() { points.map |p->Ref| { p.id } }

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

  ** Has this actor's pool been stopped
  @NoDoc Bool isStopped() { pool.isStopped }

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
    if (isStopped) return this
    send(HxMsg("sync")).get(timeout)
    return this
  }

  ** Force a house keeping cycle
  @NoDoc Future forceHouseKeeping()
  {
    // don't use houseKeepingMsg which will renew timer
    send(HxMsg("forcehk"))
  }

  ** Invoke the learn request
  @NoDoc override Future learnAsync(Obj? arg := null)
  {
    // route to ConnExt first so connectors can implement
    // learn without a dispatch to connector/openLinger
    ext.onLearn(this, arg)
  }

  ** Actor messages are routed to `ConnDispatch`
  override Obj? receive(Obj? m)
  {
    msg := (HxMsg)m
    mgr := Actor.locals["mgr"] as ConnMgr
    if (mgr == null)
    {
      try
      {
        Actor.locals["mgr"] = mgr = ConnMgr(this, ext.model.dispatchType)
      }
      catch (Err e)
      {
        log.err("Cannot initialize  ${ext.model.dispatchType}", e)
        throw e
      }
    }

    if (msg === pollMsg)
    {
      onReceiveEnter(msg)
      try
        mgr.onPoll
      catch (Err e)
        log.err("Conn.receive poll", e)
      finally
        onReceiveExit
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
      onReceiveEnter(msg)
      trace.dispatch(msg)
      return mgr.onReceive(msg)
    }
    finally
    {
      onReceiveExit
    }
  }

  private Void onReceiveEnter(HxMsg msg)
  {
    threadDebugRef.val = ConnThreadDebug(msg)
  }

  private Void onReceiveExit()
  {
    threadDebugRef.val = null
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
             proj:           $proj.platform.hostModel [$proj.version]
             ext:            $ext.typeof [$ext.typeof.pod.version]
             timeout:        $timeout
             openRetryFreq:  $openRetryFreq
             pingFreq:       $pingFreq
             linger:         $linger
             tuning:         $tuning.rec.id.toZinc
             numPoints:      $points.size
             data:           $data
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

    extra := ext.onConnDetails(this).trim
    if (!extra.isEmpty) s.add("\n").add(extra).add("\n")

    s.add("\n")
    detailsThreadDebug(s, threadDebugRef.val)

    s.add("\n")
    s.add(ext.typeof.name+".")
    ext.connActorPool->dump(s.out)

    return s.toStr
  }

  private StrBuf detailsThreadDebug(StrBuf s, ConnThreadDebug? x)
  {
    if (x == null) return s.add("currentMessage: none\n")

    s.add("currentMessage:\n")
    s.add("  id:        $x.msg.id\n")
    detailsMsgArg(s, "arg-a", x.msg.a)
    detailsMsgArg(s, "arg-b", x.msg.b)
    detailsMsgArg(s, "arg-c", x.msg.c)
    detailsMsgArg(s, "arg-d", x.msg.d)
    s.add("  dur:       $x.dur\n")
    s.add("  threadId:  $x.threadId\n")
    stackTrace := HxUtil.threadDump(x.threadId)
    s.add(stackTrace)
    while (s[-1] == '\n') s.remove(-1)
    return s.add("\n")
  }

  private Void detailsMsgArg(StrBuf s, Str name, Obj? arg)
  {
    if (arg == null) return
    str := ""
    try
      str = arg.toStr
    catch (Err e)
      str = e.toStr
    if (str.size > 100) str = str[0..<99] + "..."
    s.add("  ").add(name).add(":     ").add(str).add("\n")
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
  private const AtomicRef threadDebugRef := AtomicRef(null)
}

**************************************************************************
** ConnThreadDebug
**************************************************************************

internal const class ConnThreadDebug
{
  new make(HxMsg msg)
  {
    this.msg = msg
    this.ticks = Duration.nowTicks
    this.threadId = HxUtil.threadId
  }

  const Int ticks       // starting ticks
  const Int threadId    // name of thread
  const HxMsg msg       // messaging being processed

  Str dur()  { (Duration.now - Duration(ticks)).toLocale }
}

**************************************************************************
** ConnConfig
**************************************************************************

** ConnConfig models current state of rec dict
internal const final class ConnConfig
{
  new make(ConnExt ext, Dict rec)
  {
    model := ext.model

    this.rec           = rec
    this.dis           = rec.dis
    this.isDisabled    = rec.has("disabled")
    this.timeout       = Etc.dictGetDuration(rec, "actorTimeout", 1min).max(1sec)
    this.openRetryFreq = Etc.dictGetDuration(rec, "connOpenRetryFreq", 10sec).max(1sec)
    this.pingFreq      = Etc.dictGetDuration(rec, "connPingFreq", null)?.max(1sec)
    this.linger        = Etc.dictGetDuration(rec, "connLinger", 30sec).max(0sec)
    this.tuning        = ext.tunings.forRec(rec)
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

