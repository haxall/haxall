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

  ** Constructor
  new make(ConnLib lib, Dict rec) : super(lib.connActorPool)
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
    pt := pointsById.get(id)
    if (pt != null) return pt
    if (checked) throw Err("ConnPoint not found: $id")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  Void onUpdated(Dict newRec)
  {
    recRef.val = newRec
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const ConcurrentMap pointsById := ConcurrentMap()
  private const AtomicRef pointsList := AtomicRef(ConnPoint#.emptyList)
}