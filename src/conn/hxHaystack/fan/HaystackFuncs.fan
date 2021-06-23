//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jan 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using haystack
using axon
using hx

**
** Haystack connector functions
**
const class HaystackFuncs
{
  **
  ** Ping a `haystackConn` by asynchronously reading its 'about' URI
  ** updating tags on the connector record.
  **
  ** Examples:
  **   read(haystackConn).haystackPing
  **   haystackPing(haystackConnId)
  **
  @Axon { admin = true }
  static Obj? haystackPing(Obj conn)
  {
    "ping test"
    //HaystackExt.cur.connActor(conn).ping
  }

}