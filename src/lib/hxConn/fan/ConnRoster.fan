//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Dec 2021  Brian Frank  Creation
//

using concurrent
using haystack
using obs
using hx

**
** ConnRoster manages the data structures for conn and point lookups
** for a given connector type.  It handles the observable events.
**
internal const final class ConnRoster
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(ConnLib lib) { this.lib = lib }

//////////////////////////////////////////////////////////////////////////
// Lookups
//////////////////////////////////////////////////////////////////////////

  Conn[] conns()
  {
    connsById.vals(Conn#)
  }

  Conn? conn(Ref id, Bool checked := true)
  {
    conn := connsById.get(id)
    if (conn != null) return conn
    if (checked) throw UnknownConnErr(id.toZinc)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  Void start()
  {
    // initialize conns
    initConns

    // subscribe to connector recs
    lib.observe("obsCommits",
      Etc.makeDict([
        "obsAdds":      Marker.val,
        "obsUpdates":   Marker.val,
        "obsRemoves":   Marker.val,
        "syncable":     Marker.val,
        "obsFilter":   lib.model.connTag
      ]), ConnLib#onConnEvent)
  }

  private Void initConns()
  {
    lib.rt.db.readAllList(Filter.has(lib.model.connTag)).each |rec|
    {
      onConnAdded(rec)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Conn Rec Events
//////////////////////////////////////////////////////////////////////////

  internal Void onConnEvent(CommitObservation e)
  {
    if (e.isAdded)
    {
      onConnAdded(e.newRec)
    }
    else if (e.isUpdated)
    {
      onConnUpdated(conn(e.id), e.newRec)
    }
    else if (e.isRemoved)
    {
      onConnRemoved(conn(e.id))
    }
  }

  private Void onConnAdded(Dict rec)
  {
    conn := Conn(lib, rec)
    connsById.add(conn.id, conn)
  }

  private Void onConnUpdated(Conn conn, Dict rec)
  {
    conn.onUpdated(rec)
  }

  private Void onConnRemoved(Conn conn)
  {
    connsById.remove(conn.id)
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  Void dump()
  {
    echo("--- $lib.name roster [$connsById.size] ---")
    conns.each |c|
    {
      echo("  - $c.id.toZinc [todo]")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const ConnLib lib
  private const ConcurrentMap connsById := ConcurrentMap()

}