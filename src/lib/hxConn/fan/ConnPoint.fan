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
using hx

**
** ConnPoint models a point within a connector.
**
const final class ConnPoint
{
  new make(Conn conn, Dict rec)
  {
    this.conn   = conn
    this.id     = rec.id
    this.recRef = AtomicRef(rec)
  }

  ** Parent connector
  const Conn conn

  ** Record id
  const Ref id

  ** Current version of the record
  Dict rec() { recRef.val }
  private const AtomicRef recRef

  ** Convenience for 'rec.dis'
  Str dis() { rec.dis}

  ** Debug string
  override Str toStr() { "ConnPoint [$id.toZinc]" }

  ** Is current address supported on this point
  Bool hasCur() { t := conn.lib.model.curTag; return t != null && rec.has(t) }

  ** Is write address supported on this point
  Bool hasWrite() { t := conn.lib.model.writeTag; return t != null && rec.has(t) }

  ** Is history address supported on this point
  Bool hasHis() { t := conn.lib.model.hisTag; return t != null && rec.has(t) }

}