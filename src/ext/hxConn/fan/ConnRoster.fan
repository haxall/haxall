//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Dec 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using obs
using hx
using hxPoint

**
** ConnRoster manages the data structures for conn and point lookups
** for a given connector type.  It handles the observable events.
**
internal const final class ConnRoster
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(ConnExt ext) { this.ext = ext }

//////////////////////////////////////////////////////////////////////////
// Lookups
//////////////////////////////////////////////////////////////////////////

  Int numConns()
  {
    connsById.size
  }

  Conn[] conns()
  {
    connsList.val
  }

  Conn? conn(Ref id, Bool checked := true)
  {
    conn := connsById.get(id)
    if (conn != null) return conn
    if (checked) throw UnknownConnErr("Connector not found: $id.toZinc")
    return null
  }

  ConnPoint[] points()
  {
    pointsById.vals(ConnPoint#)
  }

  ConnPoint? point(Ref id, Bool checked := true)
  {
    pt := pointsById.get(id)
    if (pt != null) return pt
    if (checked) throw UnknownConnPointErr("Connector point not found: $id.toZinc")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  Void start(ConnModel model)
  {
    // initialize conns (which in turn initializes points)
    initConns

    // subscribe to connector rec commits
    ext.observe("obsCommits",
      Etc.makeDict([
        "obsAdds":    Marker.val,
        "obsUpdates": Marker.val,
        "obsRemoves": Marker.val,
        "syncable":   Marker.val,
        "obsFilter":  model.connTag
      ]), ConnExt#onConnEvent)

    // subscribe to connector point commits
    ext.observe("obsCommits",
      Etc.makeDict([
        "obsAdds":    Marker.val,
        "obsUpdates": Marker.val,
        "obsRemoves": Marker.val,
        "syncable":   Marker.val,
        "obsFilter":  "point and $model.connRefTag"
      ]), ConnExt#onPointEvent)

    // subscribe to connector point watches
    if (model.hasCur)
    {
      ext.observe("obsWatches",
        Etc.makeDict([
          "obsFilter": "point and $model.connRefTag"
        ]), ConnExt#onPointWatch)
    }

    // subscribe to point writes
    if (model.hasWrite)
    {
      ext.observe("obsPointWrites",
        Etc.dict1("obsFilter", model.connRefTag),
        ConnExt#onPointWrite)
    }
  }

  private Void initConns()
  {
    filter := Filter.has(ext.model.connTag)
    ext.proj.db.readAllEach(filter, Etc.emptyDict) |rec|
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
      onConnUpdated(conn(e.id), e)
    }
    else if (e.isRemoved)
    {
      onConnRemoved(conn(e.id))
    }
  }

  private Void onConnAdded(Dict rec)
  {
    // create connector instance
    conn := Conn(ext, rec)

    // add it to my lookup tables
    service := ext.fw.service
    connsById.add(conn.id, conn)
    updateConnsList
    service.addConn(conn)

    // find any points already created bound to this connector
    filter := Filter.has("point").and(Filter.eq(ext.model.connRefTag, conn.id))
    pointsList := ConnPoint[,]
    ext.proj.db.readAllEach(filter, Etc.emptyDict) |pointRec|
    {
      point := ConnPoint(conn, pointRec)
      pointsList.add(point)
      pointsById.add(point.id, point)
      service.addPoint(point)
    }
    conn.updatePointsList(pointsList)

    // now that all the points are setup, we can safely
    // initialize and start the connector
    conn.start
  }

  private Void onConnUpdated(Conn conn, CommitObservation e)
  {
    conn.send(HxMsg("connUpdated", e.newRec))
  }

  private Void onConnRemoved(Conn conn)
  {
    // send removed event
    conn.send(HxMsg("connRemoved"))

    // mark this connector as not alive anymore
    conn.kill

    // remove all its points from lookup tables
    service := ext.fw.service
    conn.points.each |pt|
    {
      service.removePoint(pt)
      pointsById.remove(pt.id)
    }

    // remove conn from lookup tables
    service.removeConn(conn)
    connsById.remove(conn.id)
    updateConnsList
  }

  private Void updateConnsList()
  {
    list := connsById.vals(Conn#)
    if (list.size > 1) Etc.sortDis(list) |Conn c->Str| { c.dis }
    connsList.val = list.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Point Events
//////////////////////////////////////////////////////////////////////////

  internal Void onPointEvent(CommitObservation e)
  {
    if (e.isAdded)
    {
      onPointAdded(e.newRec)
    }
    else if (e.isUpdated)
    {
      onPointUpdated(e)
    }
    else if (e.isRemoved)
    {
      onPointRemoved(e.id)
    }
  }

  private Void onPointAdded(Dict rec)
  {
    // lookup conn, if not found ignore it
    id := rec.id
    connRef := pointConnRef(rec)
    conn := conn(connRef, false)
    if (conn == null) return

    // check if point already exists (which might happen
    // during startup if we receive are receiving both
    // an onConnAdded and onPointAdded events)
    point := conn.point(id, false)
    if (point != null) return

    // create instance
    point = ConnPoint(conn, rec)

    // add to lookup tables
    pointsById.add(point.id, point)
    updateConnPoints(conn)
    ext.fw.service.addPoint(point)
    conn.send(HxMsg("pointAdded", point))
  }

  private Void onPointUpdated(CommitObservation e)
  {
    id := e.id
    rec := e.newRec

    // lookup existing point
    point := point(id, false)

    // if point doesn't exist it previously didn't map to a
    // connector, but now it might so give it another go
    if (point == null)
    {
      onPointAdded(rec)
      return
    }

    // if the conn ref has changed, then we consider this remove/add
    connRef := pointConnRef(rec)
    if (point.conn.id != connRef)
    {
      onPointRemoved(id)
      onPointAdded(rec)
      return
    }

    // normal update
    conn := point.conn
    if (!conn.pool.isStopped)
      conn.send(HxMsg("pointUpdated", point, rec))
  }

  private Void onPointRemoved(Ref id)
  {
    // lookup point, if not found we can ignore
    point := point(id, false)
    if (point == null) return

    // remove from lookup tables
    pointsById.remove(id)
    updateConnPoints(point.conn)
    ext.fw.service.removePoint(point)
    point.conn.send(HxMsg("pointRemoved", point))
  }

  private Void updateConnPoints(Conn conn)
  {
    acc := ConnPoint[,]
    acc.capacity = conn.points.size + 4
    pointsById.each |ConnPoint pt|
    {
      if (pt.conn === conn) acc.add(pt)
    }
    conn.updatePointsList(acc)
  }

  private Ref pointConnRef(Dict rec)
  {
    rec[ext.model.connRefTag] as Ref ?: Ref.nullRef
  }

//////////////////////////////////////////////////////////////////////////
// Watch Events
//////////////////////////////////////////////////////////////////////////

  internal Void onPointWatch(Observation e)
  {
    // parse event
    isWatch := e.subType == "watch"
    type := isWatch ? "watch" : "unwatch"
    recs := (Dict[])e["recs"]

    // walk thru the records grouping the points by connector
    groupsByConn := Ref:ConnPoint[][:]
    recs.each |rec|
    {
      // lookup point
      pt := point(rec.id, false)
      if (pt == null) return

      // add to groups keyed by connector id
      group := groupsByConn[pt.conn.id]
      if (group == null) groupsByConn[pt.conn.id] = group = ConnPoint[,] { it.capacity = recs.size }
      group.add(pt)
    }

    // fire msg to connectors
    groupsByConn.each |group|
    {
      group.first.conn.send(HxMsg(type, group))
    }
  }

//////////////////////////////////////////////////////////////////////////
// Point Write Events
//////////////////////////////////////////////////////////////////////////

  internal Void onPointWrite(WriteObservation e)
  {
    // lookup point
    point := point(e.id, false)
    if (point == null) return

    // if point has a writable address, send conn message
    if (point.isWriteEnabled)
      point.conn.send(HxMsg("write", point, ConnWriteInfo(e)))
  }

//////////////////////////////////////////////////////////////////////////
// Utiils
//////////////////////////////////////////////////////////////////////////

  Void removeAll()
  {
    service := ext.fw.service
    pointsById.each |pt| { service.removePoint(pt) }
    connsById.each |c| { service.removeConn(c) }
    updateConnsList
  }

  Void dump()
  {
    echo("--- $ext.name roster [$connsById.size conns, $pointsById.size points] ---")
    conns := conns.dup.sort |a, b| { a.dis <=> b.dis }
    conns.each |c|
    {
      echo("  - $c.id.toZinc [$c.points.size]")
      c.points.each |pt| { echo("    - $pt.id.toZinc") }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const ConnExt ext
  private const AtomicRef connsList := AtomicRef(Conn#.emptyList)
  private const ConcurrentMap connsById := ConcurrentMap()
  private const ConcurrentMap pointsById := ConcurrentMap()

}

