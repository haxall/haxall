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
using hxPoint

**
** ConnMgr manages the mutable state and logic for a connector.
** It routes to ConnDispatch for connector specific behavior.
**
internal final class ConnMgr
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor with parent connector
  new make(Conn conn, Type dispatchType)
  {
    this.conn = conn
    this.vars = conn.vars
    this.dispatch = dispatchType.make([this])
  }

//////////////////////////////////////////////////////////////////////////
// Identity/Conveniences
//////////////////////////////////////////////////////////////////////////

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

//////////////////////////////////////////////////////////////////////////
// Receive
//////////////////////////////////////////////////////////////////////////

  ** Handle actor message
  Obj? onReceive(HxMsg msg)
  {
    try
    {
      switch (msg.id)
      {
        case "ping":         return ping
        case "close":        return close("force close")
        case "sync":         return null
        case "write":        return onWrite(msg.a, msg.b)
        case "watch":        return onWatch(msg.a)
        case "unwatch":      return onUnwatch(msg.a)
        case "syncCur":      return onSyncCur(msg.a)
        case "syncHis":      return onSyncHis(msg.a, msg.b)
        case "hisPending":   return onHisPending(msg.a)
        case "learn":        return onLearn(msg.a)
        case "connUpdated":  return onConnUpdated(msg.a)
        case "pointAdded":   return onPointAdded(msg.a)
        case "pointUpdated": return onPointUpdated(msg.a, msg.b)
        case "pointRemoved": return onPointRemoved(msg.a)
        case "init":         return onInit
        case "forcehk":      return onHouseKeeping
        case "inWatch":      return pointsInWatch.toImmutable
      }
    }
    catch (Err e)
    {
      log.err("Conn.receive $msg.id", e)
      throw e
    }

    // let custom dispatch messages raise exception to caller
    return dispatch.onReceive(msg)
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
    if (!isOpen) throw NotOpenLibErr("Connector open failed", vars.err)
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
    checkWriteOnOpen
  }

  ** Force this connector closed and call `onClose`.
  ** Reason is a string message or Err exception
  Dict close(Obj? cause)
  {
    if (isClosed) return rec
    trace.phase("close", cause)
    updateConnState(ConnState.closing)
    try
      dispatch.onClose
    catch (Err e)
      log.err("onClose", e)
    vars.clearLinger
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
    openLinger.checkOpen
    return dispatch.onLearn(arg)
  }

//////////////////////////////////////////////////////////////////////////
// Updates
//////////////////////////////////////////////////////////////////////////

  private Obj? onInit()
  {
    updateStatus(true)
    updatePointsInWatch
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
    updatePointsInWatch
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

    // handle watch changes
    if (oldConfig.isCurEnabled != newConfig.isCurEnabled)
      updatePointsInWatch

    // handle tuning change
    if (oldConfig.tuning !== newConfig.tuning)
      updateBuckets

    dispatch.onPointUpdated(pt)
    return null
  }

  private Obj? onPointRemoved(ConnPoint pt)
  {
    updatePointsInWatch
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
    // set isWatched flag regardless of cur enable status
    points.each |pt| { pt.isWatchedRef.val = true }

    // filter for cur enabled points for rest of logic
    points = points.findAll |pt| { pt.isCurEnabled }
    if (points.isEmpty) return "watch [no cur points]"

    // check for quick polls
    nowTicks := Duration.nowTicks
    points.each |pt|
    {
      if (isQuickPoll(nowTicks, pt))
        pt.updateCurQuickPoll(true)
    }

    // update internal tables and handle watch lifecycle
    updatePointsInWatch
    if (!pointsInWatch.isEmpty) openPin("watch")
    if (isOpen) dispatch.onWatch(points)
    return "watch [$points.size points]"
  }

  private Bool isQuickPoll(Int nowTicks, ConnPoint pt)
  {
    if (conn.pollMode !== ConnPollMode.buckets) return false
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
    acc.capacity = conn.points.size
    conn.points.each |pt|
    {
      if (pt.isWatched && pt.isCurEnabled) acc.add(pt)
    }
    this.pointsInWatch = acc
  }

  private Void onCurHouseKeeping(Duration now, ConnPoint pt, ConnTuning tuning)
  {
    // if current not enabled, then skip this point
    if (!pt.isCurEnabled) return

    // check stale time and if time to transition from ok
    // to stale, then add it to the toStale list
    if (pt.curState.status === ConnStatus.ok &&
        !pt.isWatched &&
        now.ticks - pt.curState.lastUpdate >= tuning.staleTime.ticks)
    {
      pt.updateCurStale
    }
  }

//////////////////////////////////////////////////////////////////////////
// Writes
//////////////////////////////////////////////////////////////////////////

  private Obj? onWrite(ConnPoint pt, ConnWriteInfo info)
  {
    // if first write, then check for writeOnStart
    if (info.isFirst)
    {
      if (!pt.tuning.writeOnStart) return null
    }

    // save the received write info and clear the queued flag; we
    // always want to keep track of last write issued by system/priority
    // array independently of writeVal which is managed by hxPoint
    pt.updateWriteReceived(info)

    // check for writeMinTime to delay this write as pending
    tuning := pt.tuning
    if (tuning.writeMinTime != null)
    {
      lastWrite := Duration.nowTicks - pt.writeState.lastUpdate
      if (lastWrite < tuning.writeMinTime.ticks)
      {
        pt.updateWritePending(true)
        return null
      }
    }

    // open and verify conn was successfully opened
    openLinger
    if (isClosed)
    {
      pt.updateWriteErr(info, DownErr("closed"))
      return null
    }

    try
    {
      // convert if configured
      if (pt.writeConvert != null)
        info = ConnWriteInfo.convert(info, pt)

      // dispatch callback
      dispatch.onWrite(pt, info)
    }
    catch (Err e)
    {
      pt.updateWriteErr(info, e)
    }
    return null
  }

  private Void checkWriteOnOpen()
  {
    // short circuit if connector doesn't even support writes
    if (!lib.model.hasWrite) return

    // iterate all the points
    conn.points.each |pt|
    {
      // skip if write not enabled
      if (!pt.isWriteEnabled) return

      // skip if write already queued
      writeState := pt.writeState
      if (writeState.queued) return

      // get last write request, skip if never written
      last := writeState.lastInfo
      if (last == null) return

      // skip if tuning not configured for writeOnOpen
      if (!pt.tuning.writeOnOpen) return

      // issue write request
      sendWrite(pt, last.asOnOpen)
    }
  }

  private Void onWriteHouseKeeping(Duration now, ConnPoint pt, ConnTuning tuning)
  {
    // if write not enabled, then skip this point
    if (!pt.isWriteEnabled) return

    // if we have already queued a write during house keeping then
    // don't do any additional work until that message gets processed
    state := pt.writeState
    if (state.queued) return

    // sanity check that writeLastArg is not null
    last := state.lastInfo
    if (last == null)
    {
      pt.updateWriteQueued(false)
      pt.updateWritePending(false)
      return
    }

    // writeMinTime - check for pending write
    if (state.pending)
    {
      // clear pending write
      if (tuning.writeMinTime == null)
      {
        // if writeMinTime cleared then cancel pending writes
        pt.updateWritePending(false)
      }
      else if (now.ticks - pt.writeState.lastUpdate >= tuning.writeMinTime.ticks)
      {
        // minWriteTime has elapsed to write our pending value
        sendWrite(pt, last.asMinTime)
        pt.updateWritePending(false)
        return
      }
    }

    // writeMaxTime - check for rewrite
    if (tuning.writeMaxTime != null)
    {
      if (now.ticks - pt.writeState.lastUpdate >= tuning.writeMaxTime.ticks && rt.isSteadyState)
      {
        sendWrite(pt, last.asMaxTime)
        return
      }
    }
  }

  private Void sendWrite(ConnPoint pt, ConnWriteInfo info)
  {
    conn.send(HxMsg("write", pt, info))
    pt.updateWriteQueued(true)
  }

//////////////////////////////////////////////////////////////////////////
// His
//////////////////////////////////////////////////////////////////////////

  private Obj? onSyncHis(ConnPoint point, Span span)
  {
    openLinger
    if (isClosed)
      return point.updateHisErr(DownErr("closed"))

    try
      return dispatch.onSyncHis(point, span)
    catch (Err e)
      return point.updateHisErr(e)
  }

  private Obj? onHisPending(ConnPoint point)
  {
    point.updateHisPending
    return null
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
    quicks := pointsInWatch.findAll |pt| { pt.curState.quickPoll }
    if (!quicks.isEmpty)
    {
      trace.poll("Poll quick")
      pollBucketPoints(quicks)
    }
  }

  private Void pollBucket(Int startTicks, ConnPollBucket bucket)
  {
    // we only want to poll watched points that have cur enabled
    points := bucket.points.findAll |pt| { pt.isWatched && pt.isCurEnabled }
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
    points.each |pt| { pt.updateCurQuickPoll(false) }
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

  internal Obj? onHouseKeeping()
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
    return null
  }

  private Void doPointHouseKeeping(Duration now, ConnPoint[] toStale, ConnPoint pt)
  {
    tuning := pt.tuning
    onCurHouseKeeping(now, pt, tuning)
    onWriteHouseKeeping(now, pt, tuning)
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