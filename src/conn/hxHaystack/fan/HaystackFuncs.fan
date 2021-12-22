//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jan 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using axon
using hx
using hxConn

**
** Haystack connector functions
**
const class HaystackFuncs
{
  ** Deprecated - use `connPing()`
  @Deprecated @Axon { admin = true }
  static Future haystackPing(Obj conn)
  {
    ConnFwFuncs.connPing(conn)
  }

  ** Deprecated - use `connLearn()`
  @Deprecated @Axon { admin = true }
  static Obj? haystackLearn(Obj conn, Obj? arg := null)
  {
    ConnFwFuncs.connLearn(conn, arg)
  }

  ** Deprecated - use `connSyncCur()`
  @Deprecated @Axon { admin = true }
  static Future haystackSyncCur(Obj points)
  {
    ConnFwFuncs.connSyncCur(points)
  }

  ** Deprecated - use `connSyncHis()`
  @Deprecated @Axon { admin = true }
  static Future haystackSyncHis(Obj points, Obj? span := null)
  {
    ConnFwFuncs.connSyncHis(points, span)
  }
}