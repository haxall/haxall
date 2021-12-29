//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using hx

**
** Conn models a connection to a single endpoint.
**
const final class Conn : Actor
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Internal constructor
  internal new make(ConnLib lib, Dict rec) : super(lib.connActorPool)
  {
    this.lib    = lib
    this.id     = rec.id
    this.recRef = AtomicRef(rec)
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Runtime
  HxRuntime rt() { lib.rt }

  ** Parent connector library
  const ConnLib lib

  ** Record id
  const Ref id

  ** Display name
  Str dis() { rec.dis }

  ** Current version of the record
  Dict rec() { recRef.val }
  private const AtomicRef recRef

  ** Log for this connector
  Log log() { lib.log }

//////////////////////////////////////////////////////////////////////////
// Points
//////////////////////////////////////////////////////////////////////////

  ** Get list of all points managed by this connector.
  ConnPoint[] points() { pointsList.val }

  ** Get the point managed by this connector via its point rec id.
  ConnPoint? point(Ref id, Bool checked := true)
  {
    pt := lib.roster.point(id, false) as ConnPoint
    if (pt != null && pt.conn === this) return pt
    if (checked) throw UnknownConnPointErr("Connector point not found: $id.toZinc")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  ** Actor messages are routed to `ConnDispatch`
  override Obj? receive(Obj? msg)
  {
    dispatch := Actor.locals["d"] as ConnDispatch
    if (dispatch == null)
    {
      try
      {
        Actor.locals["d"] = lib.model.dispatchType.make([this])
      }
      catch (Err e)
      {
        log.err("Cannot initialize dispatch ${lib.model.dispatchType}", e)
        throw e
      }
    }
    return dispatch.onReceive(msg)
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Called when record is modified
  internal Void updateRec(Dict newRec)
  {
    recRef.val = newRec
  }

  ** Update the points list.
  ** Must pass mutable list which is sorted by this method.
  internal Void updatePointsList(ConnPoint[] pts)
  {
    pointsList.val = pts.sort |a, b| { a.dis <=> b.dis }.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const AtomicRef pointsList := AtomicRef(ConnPoint#.emptyList)
}