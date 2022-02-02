//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Dec 2021  Brian Frank  Creation
//

using haystack
using folio
using hx

**
** ConnDispatch provides an implementation for all callbacks.
** A subclass is created by each connector to implement the various
** callbacks and store mutable state.  All dispatch callbacks
** are executed within the parent Conn actor.
**
abstract class ConnDispatch
{
  ** Constructor with framework specific argument
  new make(Obj arg)
  {
    mgr := arg as ConnMgr ?: throw Err("Invalid constructor arg: $arg")
    this.mgr = mgr
    this.connRef = mgr.conn
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Runtime system
  HxRuntime rt() { connRef.rt }

  ** Runtime database
  Folio db() { connRef.db }

  ** Parent library
  virtual ConnLib lib() { connRef.lib }

  ** Parent connector
  Conn conn() { connRef }
  private const Conn connRef

  ** Record id
  Ref id() { conn.id }

  ** Debug tracing for this connector
  ConnTrace trace() { conn.trace }

  ** Log for this connector
  Log log() { conn.log }

  ** Display name
  Str dis() { conn.dis }

  ** Current version of the record.
  ** This dict only represents the current persistent tags.
  ** It does not track transient changes such as 'connStatus'.
  Dict rec() { conn.rec }

  ** ConnMgr wrapper which handles implementation logic
  private ConnMgr mgr

  ** Get the point managed by this connector via its point rec id.
  ConnPoint? point(Ref id, Bool checked := true) { conn.point(id, checked) }

  ** Get list of all points managed by this connector.
  ConnPoint[] points() { conn.points }

  ** Get list of points which are currently in watch.
  ConnPoint[] pointsWatched() { mgr.pointsInWatch.ro }

  ** Return if there is one or more points currently in watch.
  Bool hasPointsWatched() { mgr.hasPointsWatched }

  ** Set the `Conn.data` value.  The value must be immutable.
  Void setConnData(Obj? val) { conn.setData(mgr, val) }

  ** Set the `ConnPoint.data` value.  The value must be immutable.
  Void setPointData(ConnPoint pt, Obj? val) { pt.setData(mgr, val) }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Open the connector.  The connection will linger open based
  ** on the configured linger timeout, then automatically close.
  ** If the connector fails to open, then raise an exception.
  This open()
  {
     mgr.openLinger.checkOpen
     return this
  }

  ** Force this connector closed.
  This close(Err? cause)
  {
    mgr.close(cause)
    return this
  }

  ** Open the connection for a specific application and pin
  ** it until that application specifically closes it.  The
  ** app name is a unique key used for reference counting.
  @NoDoc This openPin(Str app)
  {
    mgr.openPin(app)
    return this
  }

  ** Close a pinned application opened by `openPin`.
  @NoDoc Void closePin(Str app)
  {
    mgr.closePin(app)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Callback to handle custom actor messages
  virtual Obj? onReceive(HxMsg msg) { throw Err("Unknown msg: $msg") }

  ** Callback to handle opening the connection.  Raise DownErr or FaultErr
  ** if the connection failed.  This callback is always called before
  ** operations such as `onPing`.
  abstract Void onOpen()

  ** Callback to handle close of the connection.
  abstract Void onClose()

  ** Callback to handle ping of the connector.  Return custom
  ** status tags such as device version, etc to store on the connector
  ** record persistently.  If there are version tags which should be
  ** removed then map those tags to Remove.val.  If ping fails then
  ** raise DownErr or FaultErr.
  abstract Dict onPing()

  ** Callback to handle learn tree navigation.  This method should
  ** return a grid where the rows are either navigation elements
  ** to traverse or points to map.  The 'learn' tag is used to indicate
  ** a row which may be "dived into" to navigate the remote system's tree.
  ** The 'learn' value is passed back to this function to get the next
  ** level of the tree.  A null arg should return the root of the learn tree.
  ** The following tags should be used to indicate points to map:
  **   - dis: display name for navigation (required for all rows)
  **   - point: marker indicating point (1 or more fooCur/His/Write)
  **   - fooCur: address if object can be mapped for cur real-time sync
  **   - fooWrite: address if object can be mapped for writing
  **   - fooHis: address if object can be mapped for history sync
  **   - kind: point kind type if known
  **   - unit: point unit if known
  **   - hisInterpolate: if point is known to be collected as COV
  **   - enum: if range of bool or multi-state is known
  **   - any other known tags to map to the learned points
  virtual Grid onLearn(Obj? arg) { throw UnsupportedErr() }

  ** Callback made periodically for manual polling.  This callback
  ** is only invoked if `Conn.pollMode` is configured as "manual".
  ** The frequency of the callback is determined by `Conn.pollFreq`.
  ** Use `pointsWatched` to list of points currently being watched.
  virtual Void onPollManual() { }

  ** Callback to poll a bucket of points with the same tuning config.
  ** Default implementation calls `onSyncCur`.  This callback is only
  ** used if the `Conn.pollMode` is configured as "buckets".
  virtual Void onPollBucket(ConnPoint[] points) { onSyncCur(points) }

  ** Callback to synchronize the given list of points.  The result
  ** of this call should be to invoke `ConnPoint.updateCurOk` or
  ** `ConnPoint.updateCurErr` on each point.  All the points
  ** are guaranteed to return true for [isCurEnabled]`ConnPoint.isCurEnabled`
  virtual Void onSyncCur(ConnPoint[] points) {}

  ** Callback when one or more points are put into watch mode.  All the
  ** points are guaranteed to return true for [isCurEnabled]`ConnPoint.isCurEnabled`
  virtual Void onWatch(ConnPoint[] points) {}

  ** Callback when one or more points are taken out of watch mode.
  virtual Void onUnwatch(ConnPoint[] points) {}

  ** Callback to write a point.  The connector should write 'info.val'
  ** to the remote system.  If successful then call `ConnPoint.updateWriteOk`.
  ** If there is an error then invoke `ConnPoint.updateWriteErr` or raise
  ** an exception.  Note the value  may have been convered from `writeVal`
  ** if `writeConvert` is configured.
  virtual Void onWrite(ConnPoint point, ConnWriteInfo event) {}

  ** Callback to synchronize the a point's history data from the
  ** connector.  The result of this callback must be to invoke
  ** `ConnPoint.updateHisOk` or `ConnPoint.updateHisErr` (or just
  ** raise exception).  The return of this method should be
  ** whatever 'updateHisXXX' returns.
  virtual Obj? onSyncHis(ConnPoint point, Span span) { throw UnsupportedErr() }

  ** Callback made periodically every few seconds to handle background tasks.
  virtual Void onHouseKeeping() {}

  ** Callback when conn record is updated
  virtual Void onConnUpdated() {}

  ** Callback when point is added to this connector
  virtual Void onPointAdded(ConnPoint pt) {}

  ** Callback when point record is updated
  virtual Void onPointUpdated(ConnPoint pt) {}

  ** Callback when point is removed from this connector
  virtual Void onPointRemoved(ConnPoint pt) {}
}