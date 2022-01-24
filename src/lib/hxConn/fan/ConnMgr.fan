//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Dec 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx

**
** ConnMgr manages the mutable state and logic for a connector.
** It routes to ConnDispatch for connector specific behavior.
**
internal final class ConnMgr
{
  ** Constructor with parent connector
  new make(Conn conn, Type dispatchType)
  {
    this.conn = conn
    this.vars = conn.vars
    this.dispatch = dispatchType.make([this])
  }

  const Conn conn
  const ConnVars vars
  HxRuntime rt() { conn.rt }
  Folio db() { conn.db }
  ConnLib lib() { conn.lib }
  Ref id() { conn.id }
  Dict rec() { conn.rec }
  Str dis() { conn.dis }
  Log log() { conn.log }
  Bool isDisabled() { conn.isDisabled }
  ConnTrace trace() { conn.trace }
  Duration timeout() { conn.timeout }
  Bool hasPointsWatched() { pointsInWatch.size > 0 }

  ** Handle actor message
  Obj? onReceive(HxMsg msg)
  {
    switch (msg.id)
    {
      case "ping":         return ping
      case "close":        return close("force close")
      case "sync":         return null
      case "watch":        return onWatch(msg.a)
      case "unwatch":      return onUnwatch(msg.a)
      case "syncCur":      return onSyncCur(msg.a)
      case "learn":        return onLearn(msg.a)
      case "connUpdated":  return onConnUpdated(msg.a)
      case "pointAdded":   return onPointAdded(msg.a)
      case "pointUpdated": return onPointUpdated(msg.a, msg.b)
      case "pointRemoved": return onPointRemoved(msg.a)
      case "init":         return onInit
      default:             return dispatch.onReceive(msg)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Open/Ping/Close
//////////////////////////////////////////////////////////////////////////

  ** Is the connection currently open
  Bool isOpen { private set }

  ** Is the connection currently closed
  Bool isClosed() { !isOpen }

  ** Raise exception if not open
  This checkOpen()
  {
    if (!isOpen) throw UnknownNotOpenLibErr("Connector open failed", vars.err)
    return this
  }

  ** Open connection and then auto-close after a linger timeout.
  This openLinger(Duration linger := conn.linger)
  {
    open("linger")
    setLinger(linger)
    return this
  }

  private Void setLinger(Duration linger)
  {
    vars.setLinger(linger)
  }

  ** Open the connection for a specific application and pin it
  ** until that application specifically closes it
  Void openPin(Str app)
  {
    if (vars.openPin(app))
    {
      trace.phase("openPin", app)
      open(app)
    }
  }

  ** Close a pinned application opened by `openPin`.
  Void closePin(Str app)
  {
    if (vars.closePin(app))
    {
      trace.phase("closePin", app)
      if (vars.openPins.isEmpty) setLinger(5sec)
    }
  }

  ** Open this connector and call `onOpen`.
  private Void open(Str app)
  {
    if (isDisabled) return
    if (isOpen) return

    trace.phase("opening...", app)
    updateConnState(ConnState.opening)
    try
    {
      dispatch.onOpen
    }
    catch (Err e)
    {
      trace.phase("open err", e)
      updateConnErr(e)
      return
    }
    isOpen = true
    updateConnOk
    trace.phase("open ok")

    // re-ping every 1hr to keep metadata fresh
    if (!openForPing && vars.lastPing < Duration.nowTicks - 1hr.ticks) ping

    // if we have points currently in watch, we need to re-subscribe them
    try
      { if (hasPointsWatched && app != "watch") onWatch(pointsInWatch) }
    catch (Err e)
      { close(e); return }

    // check for points to writeOnOpen
// TODO
//    checkWriteOnOpen
  }

  ** Force this connector closed and call `onClose`.
  ** Reason is a string message or Err exception
  Dict close(Obj cause)
  {
    if (isClosed) return rec
    trace.phase("close", cause)
    updateConnState(ConnState.closing)
    try
      dispatch.onClose
    catch (Err e)
      log.err("onClose", e)
    vars.clearLinger
    vars.clearPins
    isOpen = false
    if (cause is Err)
      updateConnErr(cause)
    else
      updateConnState(ConnState.closed)
    return rec
  }

  private Void updateConnState(ConnState state)
  {
    try
    {
      vars.updateState(state)
      conn.committer.commit1(lib, rec, "connState", state.name)
    }
    catch (ShutdownErr e) {}
    catch (Err e)
    {
      if (conn.isAlive) log.err("Conn.updateConnState", e)
    }
  }

  ** Ping this connector and call onPing.  If the connector
  ** is not currently open then call `openLinger`
  Dict ping()
  {
    // ensure open
    result := rec
    openForPing = true
    try
      openLinger
    finally
      openForPing = false
    if (!isOpen) return result

    // perform onPing calback
    trace.phase("ping")
    Dict? r
    try
    r = dispatch.onPing
    catch (Err e)
      { updateConnErr(e); return result }
    vars.pinged

    // update ping/version tags only if stuff has changed
    changes := Str:Obj[:]
    r.each |v, n|
    {
      if (v === Remove.val || v == null) { if (rec.has(n)) changes[n] = Remove.val }
      else { if (rec[n] != v) changes[n] = v }
    }

    if (!changes.isEmpty)
      result = commit(Diff(rec, changes, Diff.force)).waitFor(timeout).dict

    return result
  }

  Grid onLearn(Obj? arg)
  {
    openLinger
    return dispatch.onLearn(arg)
  }

//////////////////////////////////////////////////////////////////////////
// Updates
//////////////////////////////////////////////////////////////////////////

  private Obj? onInit()
  {
    updateStatus(true)
    updateBuckets
    return null
  }

  private Obj? onConnUpdated(Dict newRec)
  {
    // update config
    oldConfig := conn.config
    newConfig := ConnConfig(lib, newRec)
    conn.setConfig(this, newConfig)

    // handle disable transition
    if (oldConfig.isDisabled != newConfig.isDisabled)
    {
      // if transitioning to disalbed, close
      if (newConfig.isDisabled) close("disabled")

      // update status
      this.vars.resetStats
      updateStatus

      // if transitioning to enable check if we should re-open
      if (!newConfig.isDisabled) checkReopen
    }

    // handle tuning change
    if (oldConfig.tuning !== newConfig.tuning)
      updateBuckets

    dispatch.onConnUpdated
    return null
  }

  private Obj? onPointAdded(ConnPoint pt)
  {
    updateBuckets
    pt.updateStatus
    dispatch.onPointAdded(pt)
    return null
  }

  private Obj? onPointUpdated(ConnPoint pt, Dict newRec)
  {
    oldConfig := pt.config
    newConfig := ConnPointConfig(lib, newRec)
    pt.setConfig(this, newConfig)

    // handle transitions which require status update
    if (oldConfig.isStatusUpdate(newConfig))
      pt.updateStatus

    // handle tuning change
    if (oldConfig.tuning !== newConfig.tuning)
      updateBuckets

    dispatch.onPointUpdated(pt)
    return null
  }

  private Obj? onPointRemoved(ConnPoint pt)
  {
    updateBuckets
    dispatch.onPointRemoved(pt)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Cur/Watches
//////////////////////////////////////////////////////////////////////////

  private Obj? onSyncCur(ConnPoint[] points)
  {
    points = points.findAll |pt| { pt.isCurEnabled }
    if (points.isEmpty) return "syncCur [no cur points]"

    openLinger.checkOpen
    dispatch.onSyncCur(points)
    return "syncCur [$points.size points]"
  }

  private Obj? onWatch(ConnPoint[] points)
  {
    points = points.findAll |pt| { pt.isCurEnabled }
    if (points.isEmpty) return "watch [no cur points]"

    nowTicks := Duration.nowTicks
    points.each |pt|
    {
      pt.isWatchedRef.val = true
      if (isQuickPoll(nowTicks, pt))
        pt.curQuickPoll = true
    }
    updatePointsInWatch
    if (!pointsInWatch.isEmpty) openPin("watch")
    if (isOpen) dispatch.onWatch(points)
    return "watch [$points.size points]"
  }

  private Bool isQuickPoll(Int nowTicks, ConnPoint pt)
  {
    if (!rt.isSteadyState) return false
    curState := pt.curState
    if (curState.lastUpdate <= 0) return true
    return nowTicks - curState.lastUpdate > pt.tuning.pollTime.ticks
  }

  private Obj? onUnwatch(ConnPoint[] points)
  {
    if (points.isEmpty) return null
    points.each |pt| { pt.isWatchedRef.val = false }
    updatePointsInWatch
    dispatch.onUnwatch(points)
    if (pointsInWatch.isEmpty) closePin("watch")
    return null
  }

  private Void updatePointsInWatch()
  {
    acc := ConnPoint[,]
    conn.points.each |pt| { if (pt.isWatched) acc.add(pt) }
    this.pointsInWatch = acc
  }

//////////////////////////////////////////////////////////////////////////
// Polling
//////////////////////////////////////////////////////////////////////////

  internal Void onPoll()
  {
    if (isClosed) return
    vars.polled
    switch (conn.pollMode)
    {
      case ConnPollMode.manual:  onPollManual
      case ConnPollMode.buckets: onPollBuckets
    }
  }

  private Void onPollManual()
  {
    trace.poll("poll manual", null)
    dispatch.onPollManual
  }

  private Void onPollBuckets()
  {
    // short circuit common cases
    pollBuckets := conn.pollBuckets
    if (pollBuckets.isEmpty || !hasPointsWatched || isClosed) return

    // check if its time to poll any buckets
    pollBuckets.each |bucket|
    {
      now := Duration.nowTicks
      if (now >= bucket.nextPoll) pollBucket(now, bucket)
    }

    // check for quick polls which didn't get handled by their bucket
    quicks := pointsInWatch.findAll |pt| { pt.curQuickPoll }
    if (!quicks.isEmpty)
    {
      trace.poll("Poll quick")
      pollBucketPoints(quicks)
    }
  }

  private Void pollBucket(Int startTicks, ConnPollBucket bucket)
  {
    // we only want to poll watched points
    points := bucket.points.findAll |pt| { pt.isWatched }
    if (points.isEmpty) return

    try
    {
      trace.poll("Poll bucket", bucket.tuning.dis)
      pollBucketPoints(points)
    }
    finally
    {
      bucket.updateNextPoll(startTicks)
    }
  }

  private Void pollBucketPoints(ConnPoint[] points)
  {
    points.each |pt| { pt.curQuickPoll = false }
    dispatch.onPollBucket(points)
  }

  private Void updateBuckets()
  {
    // short circuit if not using buckets mode
    if (conn.pollMode !== ConnPollMode.buckets) return

    // save olds buckets by tuning id so we can reuse state
    oldBuckets := Ref:ConnPollBucket[:]
    oldBuckets.setList(conn.pollBuckets) |b| { b.tuning.id }

    // group by tuning id
    byTuningId := Ref:ConnPoint[][:]
    conn.points.each |pt|
    {
      tuningId := pt.tuning.id
      bucket := byTuningId[tuningId]
      if (bucket == null) byTuningId[tuningId] = bucket = ConnPoint[,]
      bucket.add(pt)
    }

    // flatten to list
    acc := ConnPollBucket[,]
    byTuningId.each |points|
    {
      tuning := points.first.tuning
      state := oldBuckets[tuning.id]?.state ?: ConnPollBucketState(tuning)
      acc.add(ConnPollBucket(conn, tuning, state, points))
    }

    // sort by poll time; this could potentially get out of
    // order if ConnTuning have their pollTime changed - but
    // that is ok because sort order is for display, not logic
    conn.setPollBuckets(this, acc.sort.toImmutable)
  }

//////////////////////////////////////////////////////////////////////////
// House Keeping
//////////////////////////////////////////////////////////////////////////

  internal Void onHouseKeeping()
  {
    // check if we need should perform a re-open attempt
    checkReopen

    // check for auto-ping
    checkAutoPing

    // if have a linger open, then close connector
    if (vars.lingerExpired && vars.openPins.isEmpty)
       close("linger expired")

    // check points
    now := Duration.now
    toStale := ConnPoint[,]
    conn.points.each |pt|
    {
      try
        doPointHouseKeeping(now, toStale, pt)
      catch (Err e)
        log.err("doPointHouseKeeping($pt.dis)", e)
    }

    // stale transition
    if (!toStale.isEmpty)
    {
      toStale.each |pt|
      {
        try
          pt.updateCurStale
        catch (Err e)
          log.err("doHouseKeeping updateCurStale: $pt.dis", e)
      }
    }

    // dispatch callback
    dispatch.onHouseKeeping
  }

  private Void doPointHouseKeeping(Duration now, ConnPoint[] toStale, ConnPoint pt)
  {
    tuning := pt.tuning
    // onCurHouseKeeping(now, toStale, pt, tuning)
    // onWriteHouseKeeping(now, pt, tuning)
  }

  private Void checkAutoPing()
  {
    pingFreq := conn.pingFreq
    if (pingFreq == null) return
    now := Duration.nowTicks
    if (now - vars.lastPing <= pingFreq.ticks) return
    if (now - vars.lastAttempt <= pingFreq.ticks) return
    if (!rt.isSteadyState) return
    ping
  }

  private Void checkReopen()
  {
    // if already open, disabled, or no pinned apps in watch bail
    if (isOpen || isDisabled || vars.openPins.isEmpty) return

    try
    {
      // try ping every 10sec which forces watch
      // subscription on a new connection
      if (Duration.nowTicks - vars.lastErr > conn.openRetryFreq.ticks) ping
    }
    catch (Err e) log.err("checkReopenWatch", e)
  }

//////////////////////////////////////////////////////////////////////////
// Status
//////////////////////////////////////////////////////////////////////////

  private Void updateConnOk()
  {
    vars.updateOk
    updateStatus
  }

  private Void updateConnErr(Err err)
  {
    vars.updateErr(err)
    updateStatus
  }

  private Void updateStatus(Bool forcePoints := false)
  {
    // compute status and error message
    ConnStatus? status
    curErr := vars.err
    Obj? errStr
    state := isOpen ? ConnState.open : ConnState.closed
    if (rec.has("disabled"))
    {
      status = ConnStatus.disabled
      errStr = null
    }
    else if (curErr != null)
    {
      status = ConnStatus.fromErr(curErr)
      errStr = ConnStatus.toErrStr(curErr)
    }
    else if (vars.lastOk != 0)
    {
      status = ConnStatus.ok
      errStr = null
    }
    else
    {
      status = ConnStatus.unknown
      errStr = null
    }

    // update my status
    statusModified := vars.status !== status
    vars.updateStatus(status, state)
    conn.committer.commit3(lib, rec, "connStatus", status.name, "connState", state.name, "connErr", errStr)

    // if we changed the status, then update points
    if (statusModified || forcePoints)
      conn.points.each |pt| { pt.onConnStatus }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private FolioFuture commit(Diff diff)
  {
    db.commitAsync(diff)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private ConnDispatch dispatch
  private Bool openForPing
  internal ConnPoint[] pointsInWatch := [,]
}