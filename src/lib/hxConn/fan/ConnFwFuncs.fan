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
  ** Perform a ping on the given connector and return a future.  The future
  ** result is a dict for the connector record.  The 'conn' parameter may
  ** be anything acceptable by `toRecId()`.
  **
  ** Examples:
  **   read(conn).connPing
  **   connPing(connId)
  **
  @Axon { admin = true }
  static Future connPing(Obj conn) { throw Err("TODO") }

  **
  ** Perform a learn on the given connector and return a future.
  ** The future result is the learn grid.  The 'conn' parameter may
  ** be anything acceptable by `toRecId()`.  The 'arg' is an opaque
  ** identifier used to walk the learn tree via the 'learn' column.
  **
  ** Examples:
  **   connLearn(connId, learnArg)
  **
  @Axon { admin = true }
  static Future connLearn(Obj conn, Obj? arg := null) { throw Err("TODO") }

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
}