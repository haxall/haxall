//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jan 2022  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx

**
** ConnService manages the project wide database of connector libraries,
** connectors, and points.  The service implementation is registered by
** the ConnFwLib.  It uses only the mixins (not the concrete classes) so
** that can be used by both the new and classic connector framework as
** a single registry to provide a consistent UI.
**
@NoDoc
const class ConnService : HxConnService
{

//////////////////////////////////////////////////////////////////////////
// HxConnService - Libs
//////////////////////////////////////////////////////////////////////////

  override HxConnLib[] libs()
  {
    libData.list
  }

  override HxConnLib? lib(Str name, Bool checked := true)
  {
    lib := libData.byName.get(name)
    if (lib != null) return lib
    if (checked) throw UnknownConnLibErr(name)
    return null
  }

  private ConnServiceLibData libData() { libDataRef.val }

//////////////////////////////////////////////////////////////////////////
// HxConnService - Conns
//////////////////////////////////////////////////////////////////////////

  override HxConn[] conns()
  {
    connsById.vals(HxConn#)
  }

  override HxConn? conn(Ref id, Bool checked := true)
  {
    conn := connsById.get(id)
    if (conn != null) return conn
    if (checked) throw UnknownConnErr("Connector not found: $id.toZinc")
    return null
  }

  override Bool isConn(Ref id)
  {
    connsById.get(id) != null
  }

//////////////////////////////////////////////////////////////////////////
// HxConnService - Points
//////////////////////////////////////////////////////////////////////////

  override HxConnPoint[] points()
  {
    pointsById.vals(HxConnPoint#)
  }

  override HxConnPoint? point(Ref id, Bool checked := true)
  {
    point := pointsById.get(id)
    if (point != null) return point
    if (checked) throw UnknownConnPointErr("Connector point not found: $id.toZinc")
    return null
  }

  override Bool isPoint(Ref id)
  {
    pointsById.get(id) != null
  }

//////////////////////////////////////////////////////////////////////////
// Add/Removes
//////////////////////////////////////////////////////////////////////////

  Void addLib(HxConnLib lib)
  {
    while (true)
    {
      oldData := libData
      newData := oldData.add(lib)
      if (libDataRef.compareAndSet(oldData, newData)) break
    }
  }

  Void removeLib(HxConnLib lib)
  {
    while (true)
    {
      oldData := libData
      newData := oldData.remove(lib)
      if (libDataRef.compareAndSet(oldData, newData)) break
    }
  }

  Void addConn(HxConn conn)
  {
    connsById.set(conn.id, conn)
  }

  Void removeConn(HxConn conn)
  {
    connsById.remove(conn.id)
  }

  Void addPoint(HxConnPoint pt)
  {
    pointsById.set(pt.id, pt)
  }

  Void removePoint(HxConnPoint pt)
  {
    pointsById.remove(pt.id)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const AtomicRef libDataRef := AtomicRef(ConnServiceLibData.makeEmpty)
  private const ConcurrentMap connsById := ConcurrentMap()
  private const ConcurrentMap pointsById := ConcurrentMap()
}

**************************************************************************
** ConnServiceLibs
**************************************************************************

internal const class ConnServiceLibData
{
  static new makeEmpty() { make(Str:HxConnLib[:]) }

  private new make(Str:HxConnLib byName)
  {
    this.list   = byName.vals.sort |a, b| { a.name <=> b.name }
    this.byName = byName
  }

  This add(HxConnLib lib)
  {
    make(byName.dup.set(lib.name, lib))
  }

  This remove(HxConnLib lib)
  {
    make(byName.dup { it.remove(lib.name) })
  }

  const HxConnLib[] list := [,]
  const Str:HxConnLib byName := [:]
}