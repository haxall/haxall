//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using axon
using hx

**
** Connector framework functions
**
@NoDoc
const class ConnFwFuncs
{
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
  ** Return a future which completes when the sync has completed.
  ** The future result is a list of dicts for the updated point records.
  **
  ** Examples:
  **   readAll(bacnetCur).connSyncCur
  **
  @Axon { admin = true }
  static Future connSyncCur(Obj points) { throw Err("TODO") }

  **
  ** Perform a remote sync of history data for the given points.
  ** The 'points' parameter may be anything acceptable by `toRecIdList()`.
  ** The 'span' parameter is anything acceptable by `toSpan()`; or use 'null'
  ** to sync from each point's `hisEnd` tag.  Return a future which
  ** completes when the sync has completed.  The future result is a list
  ** of dicts for the updated point records.
  **
  ** Examples:
  **   readAll(haystackHis).connSyncHis(null)
  **
  @Axon { admin = true }
  static Future connSyncHis(Obj points, Obj? span) { throw Err("TODO") }

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
  ** Disable tracing on every connector in the database.
  **
  @Axon { admin = true }
  static Void connTraceDisableAll()
  {
    curContext.rt.conn.conns.each |hx|
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
  static Grid connTrace(Obj conn)
  {
    // map arg to connector
    cx := HxContext.curHx
    id := Etc.toId(conn)
    if (id.isNull) return Etc.emptyGrid
    c  := toConn(id)

    // meta data used by trace view
    meta := Str:Obj[
      "conn": c.rec,
      "enabled": c.trace.isEnabled,
      "icon": c.lib.icon,
      ]

    // read the trace, setup feed, and map to grid
    list := c.trace.read
    if (cx.feedIsEnabled)
    {
      ts := list.last?.ts ?: DateTime.now
      cx.feedAdd(ConnTraceFeed(c.trace, ts), meta)
    }
    return ConnTraceMsg.toGrid(list, meta)
  }

  ** Current context
  private static HxContext curContext() { HxContext.curHx }

  ** Coerce conn to a HxConn instance (new or old framework)
  private static HxConn toHxConn(Obj conn)
  {
    curContext.rt.conn.conn(Etc.toId(conn))
  }

  ** Coerce conn to a Conn instance (new framework only)
  private static Conn toConn(Obj conn)
  {
    hx := toHxConn(conn)
    return hx as Conn ?: throw Err("$hx.lib.name connector uses classic framework [$hx.rec.dis]")
  }
}


