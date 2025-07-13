//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using xeto
using haystack
using axon
using hx

**
** Connector framework functions
**
@NoDoc
const class ConnFwFuncs
{
  ** Return the points for a connector as list of dicts.  The 'conn'
  ** parameter may be anything accepted by `toRecId()`.  If 'conn' cannot be
  ** be mapped to an active connector then raise an exception or return an
  ** empty list based on checked flag.
  **
  ** Examples:
  **   read(haystackConn).connPoints
  **   connPoints(@my-conn-id)
  @Axon
  static Dict[] connPoints(Obj conn, Bool checked := true)
  {
    cx := curContext
    id := Etc.toId(conn)
    c := cx.rt.exts.conn.conn(id, false)
    if (c isnot Conn)
    {
      if (!checked) return Dict#.emptyList
      if (c == null) throw UnknownConnErr(id.toZinc)
      throw classicConnErr(c)
    }
    return cx.db.readByIdsList(((Conn)c).pointIds)
  }

  **
  ** Perform a ping on the given connector and return a future.
  ** The future result is the connector rec dict.  The 'conn' parameter
  ** may be anything accepted by `toRecId()`.
  **
  ** Examples:
  **   read(conn).connPing
  **   connPing(connId)
  **
  @Axon { admin = true }
  static Future connPing(Obj conn)
  {
    toHxConn(conn).ping
  }

  **
  ** Force the given connector closed and return a future.
  ** The future result is the connector rec dict.  The 'conn'
  ** parameter may be anything accepted by `toRecId()`.
  **
  ** Examples:
  **   read(conn).connClose
  **   connClose(connId)
  **
  @Axon { admin = true }
  static Future connClose(Obj conn)
  {
    toHxConn(conn).close
  }

  **
  ** Perform a learn on the given connector and return a future.
  ** The future result is the learn grid.  The 'conn' parameter may
  ** be anything acceptable by `toRecId()`.  The 'arg' is an opaque
  ** identifier used to walk the learn tree via the 'learn' column.
  ** Pass null for 'arg' to return the root of the learn tree.
  **
  ** Examples:
  **   connLearn(connId, learnArg)
  **
  @Axon { admin = true }
  static Future connLearn(Obj conn, Obj? arg := null)
  {
    toHxConn(conn).learnAsync(arg)
  }

  **
  ** Perform a remote sync of current values for the given points.
  ** The 'points' parameter may be anything acceptable by `toRecIdList()`.
  ** Return a list of futures for each unique connector.  The result
  ** of each future is unspecified.  Also see `docHaxall::Conns#cur`.
  **
  ** Examples:
  **   readAll(bacnetCur).connSyncCur
  **
  @Axon { admin = true }
  static Future[] connSyncCur(Obj points)
  {
    cx := curContext
    futures := Future[,]
    connPoints := toPoints(points, cx)
    ConnUtil.eachConnInPointIds(cx.rt, connPoints) |c, pts|
    {
      futures.add(c.syncCur(pts))
    }
    return futures
  }

  **
  ** Perform a remote sync of history data for the given points.
  ** The 'points' parameter may be anything acceptable by `toRecIdList()`.
  ** The 'span' parameter is anything acceptable by `toSpan()`.  Or pass
  ** null for span to perform a sync for items after the point's `hisEnd`.
  ** This blocks the calling thread until each point is synchronized one
  ** by one.  Normally it should only be called within a task.  The result
  ** from this function is undefined.  Also see `docHaxall::Conns#hisSync`.
  **
  ** Examples:
  **   readAll(haystackHis).connSyncHis(null)
  **
  @Axon { admin = true }
  static Obj? connSyncHis(Obj points, Obj? span := null)
  {
    cx := curContext
    connPoints := toPoints(points, cx)
    return ConnSyncHis(cx, connPoints, span).run
  }

  **
  ** Return debug details for a connector or a connector point.
  ** The argument is anything acceptable by `toRecId()`.  The result
  ** is returned as a plain text string.
  **
  @Axon { admin = true }
  static Obj connDetails(Obj obj)
  {
    if (obj is List) return connDetails(((List)obj)[0])
    if (obj is ConnPoint) return ((ConnPoint)obj).details
    cx := curContext
    id := Etc.toId(obj)
    return cx.rt.exts.conn.point(id, false)?.details ?: cx.rt.exts.conn.conn(id).details
  }

  **
  ** Select a group of points explicitly via specific connector library
  ** or connector.  This function is required when points are associated
  ** with multiple connectors.  Pass a connector library name to select
  ** for a protocol.  Or pass a connector id/rec to select via a specific
  ** connector.  Also see `docHaxall::Conns#multipleConns`.
  **
  ** Examples:
  **    // explicitly sync via the SQL connector library
  **    readAll(sqlConnRef).connPointsVia("sql").connSyncHis
  **
  **    // get debug details for specific connector
  **    connPointsVia(pt, pt->bacnetConnRef).connDetails
  **
  @Axon { admin = true }
  static Obj connPointsVia(Obj points, Obj libOrConn)
  {
    cx := curContext
    pointIds := Etc.toIds(points)

    // string is library name
    if (libOrConn is Str)
    {
      ext := (ConnExt)cx.rt.exts.get(libOrConn)
      return pointIds.map |id->ConnPoint| { ext.point(id) }
    }

    // must be connector
    conn := toConn(libOrConn)
    return pointIds.map |id->ConnPoint| { conn.point(id) }
  }

  ** To list of connector points as id or result of connPointsVia
  private static ConnPoint[] toPoints(Obj points, Context cx)
  {
    if (points is ConnPoint) return ConnPoint[points]
    if (points is List)
    {
      return ((List)points).map |x->ConnPoint|
      {
        if (x is ConnPoint) return x
        return cx.rt.exts.conn.point(Etc.toId(x))
      }
    }
    return Etc.toIds(points).map |id->ConnPoint|
    {
      return cx.rt.exts.conn.point(id)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Tracing
//////////////////////////////////////////////////////////////////////////

  **
  ** Return true or false if given connector has its tracing enabled.
  ** The 'conn' parameter can be anything acceptable by `toRecId()`.
  **
  @Axon { admin = true }
  static Bool connTraceIsEnabled(Obj conn)
  {
    toConn(conn).trace.isEnabled
  }

  **
  ** Enable tracing on the given connector.
  ** The 'conn' parameter can be anything acceptable by `toRecId()`.
  **
  @Axon { admin = true }
  static Void connTraceEnable(Obj conn)
  {
    toConn(conn).trace.enable
  }

  **
  ** Disable tracing on the given connector.
  ** The 'conn' parameter can be anything acceptable by `toRecId()`.
  **
  @Axon { admin = true }
  static Void connTraceDisable(Obj conn)
  {
    toConn(conn).trace.disable
  }

  **
  ** Clear the trace log for the given connector.
  ** The 'conn' parameter can be anything acceptable by `toRecId()`.
  **
  @Axon { admin = true }
  static Void connTraceClear(Obj conn)
  {
    toConn(conn).trace.clear
  }

  **
  ** Disable tracing on every connector in the database.
  **
  @Axon { admin = true }
  static Void connTraceDisableAll()
  {
    curContext.rt.exts.conn.conns.each |hx|
    {
      c := hx as Conn
      if (c != null) c.trace.disable
    }
  }

  **
  ** Read a connector trace log as a grid.  If tracing is not enabled
  ** for the given connector, then an empty grid is returned.  The 'conn'
  ** parameter may be anything acceptable by `toRecId()`.
  **
  ** Examples:
  **   read(conn).connTrace
  **   connTrace(connId)
  **
  @Axon { admin = true }
  static Grid connTrace(Obj conn, Dict? opts := null)
  {
    // map arg to connector
    cx := Context.cur
    id := Etc.toId(conn)
    if (id.isNull) return Etc.emptyGrid
    c  := toConn(id)

    // meta data used by trace view
    meta := Str:Obj[
      "conn": c.rec,
      "enabled": c.trace.isEnabled,
      "icon": c.ext.icon,
      ]

    // read the trace, setup feed, and map to grid
    list := c.trace.read
    if (cx.feedIsEnabled)
    {
      ts := list.last?.ts ?: DateTime.now
      cx.feedAdd(ConnTraceFeed(cx, c.trace, ts, opts), meta)
    }
    list = ConnTraceMsg.applyOpts(list, opts)
    return ConnTraceMsg.toGrid(list, meta)
  }

  ** Get the internal list of pointsInWatch for debugging
  @NoDoc @Axon { admin = true }
  static Dict[] connPointsInWatch(Obj conn)
  {
    ((ConnPoint[])toConn(conn).send(HxMsg("inWatch")).get(null)).map |pt->Dict| { pt.rec }
  }

  ** Current context
  private static Context curContext() { Context.cur }

  ** Coerce conn to a HxConn instance (new or old framework)
  private static HxConn toHxConn(Obj conn)
  {
    curContext.rt.exts.conn.conn(Etc.toId(conn), true)
  }

  ** Coerce conn to a Conn instance (new framework only)
  private static Conn toConn(Obj conn)
  {
    hx := toHxConn(conn)
    return hx as Conn ?: throw classicConnErr(hx)
  }

  ** Return exception to use for using classic connector
  private static Err classicConnErr(HxConn c)
  {
    Err("$c.ext.name connector uses classic framework [$c.rec.dis]")
  }
}

