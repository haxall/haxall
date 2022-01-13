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
** ConnState manages the mutable state and logic for a connector.
** It routes to ConnDispatch for connector specific behavior.
**
internal final class ConnState
{
  ** Constructor with parent connector
  new make(Conn conn, Type dispatchType)
  {
    this.conn = conn
    this.dispatch = dispatchType.make([this])
  }

  const Conn conn
  HxRuntime rt() { conn.rt }
  Folio db() { conn.db }
  Ref id() { conn.id }
  Dict rec() { conn.rec }
  Str dis() { conn.dis }
  Log log() { conn.log }
  ConnTrace trace() { conn.trace }
  Duration timeout() { conn.timeout }
  Bool hasPointsWatched() { pointsInWatch.size > 0 }

  ** Handle actor message
  Obj? onReceive(HxMsg msg)
  {
    switch (msg.id)
    {
      case "ping":         return ping
      case "close":        return close(null)
      case "sync":         return null
      case "watch":        onWatch(msg.a); return null
      case "unwatch":      onUnwatch(msg.a); return null
      case "learn":        return onLearn(msg.a)
      case "connUpdated":  dispatch.onConnUpdated; return null
      case "pointAdded":   dispatch.onPointAdded(msg.a); return null
      case "pointUpdated": dispatch.onPointUpdated(msg.a); return null
      case "pointRemoved": dispatch.onPointRemoved(msg.a); return null
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
    if (!isOpen) throw UnknownNotOpenLibErr("Connector open failed", curErr)
    return this
  }

  ** Open connection and then auto-close after a linger timeout.
  This openLinger(Duration linger := conn.linger)
  {
    open("")
    setLinger(linger)
    return this
  }

  private Void setLinger(Duration linger)
  {
    x := Duration.now + linger
    if (lingerClose != null) x = x.max(lingerClose)
    lingerClose = x
  }

  ** Open the connection for a specific application and pin it
  ** until that application specifically closes it
  Void openPin(Str app)
  {
    openPins[app] = app
    open(app)
  }

  ** Close a pinned application opened by `openPin`.
  Void closePin(Str app)
  {
    openPins.remove(app)
    if (openPins.isEmpty) setLinger(5sec)
  }

  ** Open this connector and call `onOpen`.
  private Void open(Str app)
  {
    if (status.isDisabled) return
    if (isOpen) return

    updateConnState("opening")
    try
      dispatch.onOpen
    catch (Err e)
      { updateConnErr(e); return }
    isOpen = true
    updateConnOk

    // re-ping every 1hr to keep metadata fresh
    if (!openForPing && lastPing < Duration.nowTicks - 1hr.ticks) ping

    // if we have points currently in watch, we need to re-subscribe them
    /*
    try
      { if (hasPointsWatched && app != "watch") doWatch(pointsInWatch) }
    catch (Err e)
      { close(e); return }

    // check for points to writeOnOpen
    checkWriteOnOpen
    */
  }

  ** Force this connector closed and call `onClose`.
  Dict close(Err? cause)
  {
    if (isClosed) return rec
trace.poll("TODO close", cause)
    updateConnState("closing")
    try
      dispatch.onClose
    catch (Err e)
      log.err("onClose", e)
    lingerClose = null
    openPins.clear
    isOpen = false
    if (cause != null)
      updateConnErr(cause)
    else
      updateConnState("closed")
    return rec
  }

  private Void updateConnState(Str state)
  {
    try
    {
      commit(Diff(rec, Etc.makeDict1("connState", state), Diff.forceTransient))
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
    Dict? r
    try
    r = dispatch.onPing
    catch (Err e)
      { updateConnErr(e); return result }
    lastPing = Duration.nowTicks
    updateConnOk

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
// Watches
//////////////////////////////////////////////////////////////////////////

  private Void onWatch(ConnPoint[] points)
  {
    if (points.isEmpty) return
    nowTicks := Duration.nowTicks
    points.each |pt|
    {
      pt.isWatchedRef.val = true
      /* TODO
      if (isQuickPoll(nowTicks, pt))
        pt.curQuickPoll = true
      */
    }
    updatePointsInWatch
    if (!pointsInWatch.isEmpty) openPin("watch")
    if (isOpen) dispatch.onWatch(points)
    return null
  }

/* TODO
  private Bool isQuickPoll(Int nowTicks, ConnPoint pt)
  {
    if (!rt.isSteadyState) return false
    if (pt.curLastOk == 0) return true
    return nowTicks - pt.curLastOk > pt.tuning.pollTime.ticks
  }
*/

  private Void onUnwatch(ConnPoint[] points)
  {
    if (points.isEmpty) return
    points.each |pt| { pt.isWatchedRef.val = false }
    updatePointsInWatch
    dispatch.onUnwatch(points)
    if (pointsInWatch.isEmpty) closePin("watch")
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
    if (lingerClose != null && Duration.now > lingerClose && openPins.isEmpty)
       close(null)

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
    if (now - lastPing <= pingFreq.ticks) return
    if (now - lastConnAttempt <= pingFreq.ticks) return
    if (!rt.isSteadyState) return
    ping
  }

  private Void checkReopen()
  {
    // if already open, disabled, or no pinned apps in watch bail
    if (isOpen || status.isDisabled || openPins.isEmpty) return

    try
    {
      // try ping every 10sec which forces watch
      // subscription on a new connection
      if (Duration.nowTicks - lastConnFail > conn.openRetryFreq.ticks) ping
    }
    catch (Err e) log.err("checkReopenWatch", e)
  }

//////////////////////////////////////////////////////////////////////////
// Status
//////////////////////////////////////////////////////////////////////////

  ** Current connection status.
  ConnStatus status := ConnStatus.unknown { private set  }

  private Void updateConnOk()
  {
    this.lastConnOk = Duration.nowTicks
    this.curErr = null
    updateStatus
  }

  private Void updateConnErr(Err err)
  {
    this.lastConnFail = Duration.nowTicks
    this.curErr = err
    updateStatus
  }

  private Void updateStatus()
  {
    // compute status and error message
    ConnStatus? status
    Obj? errStr
    state := isOpen ? "open" : "closed"
    if (rec.has("disabled"))
    {
      status = ConnStatus.disabled
      errStr = Remove.val
    }
    else if (curErr != null)
    {
      status = ConnStatus.fromErr(curErr)
      errStr = ConnStatus.toErrStr(curErr)
    }
    else if (lastConnOk != 0)
    {
      status = ConnStatus.ok
      errStr = Remove.val
    }
    else
    {
      status = ConnStatus.unknown
      errStr = Remove.val
    }

    // update my status
    this.status = status
    changes := Etc.makeDict3("connStatus", status.name, "connState", state, "connErr", errStr)
    commit(Diff(rec, changes, Diff.forceTransient))
    /*
    diffs := Diff[,]
    diffs.capacity = 1 + points.size
    tags := Etc.makeDict3("connStatus", status.name, "connState", state, "connErr", errStr)
    diffs.add(Diff(rec, tags, Diff.forceTransient))

    // update my points status
    points.each |pt| { diffs.add(Diff(pt.rec, pt.updateStatus, Diff.forceTransient)) }

    // commit everything
    try
    {
      proj.commitAll(diffs).each |diff, i|
      {
        if (i == 0)
          actor.recRef.val = diff.newRec
        else
          point(diff.id).rec = diff.newRec
      }
    }
    catch (ShutdownErr e) {}
    catch (Err e) log.err("Conn.updateStatus($status): $dis", e)
    */
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
  private Int lastPing
  private Int lastConnFail
  private Int lastConnOk
  private Int lastConnAttempt() { lastConnFail.max(lastConnOk) }
  private Err? curErr
  private Duration? lingerClose
  internal ConnPoint[] pointsInWatch := [,]
  private Str:Str openPins := [:]
  private Int lastPoll := 0
}