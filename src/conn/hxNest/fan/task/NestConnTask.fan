//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

using xeto
using haystack
using hxConn

**
** Base class for Nest connector tasks
**
internal abstract class NestConnTask
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(NestDispatch dispatch)
  {
    this.dispatch = dispatch
  }

  NestDispatch dispatch { private set }
  Nest client() { dispatch.client }
  Conn conn() { dispatch.conn }
  virtual Log log() { dispatch.log }

//////////////////////////////////////////////////////////////////////////
// ConnTask
//////////////////////////////////////////////////////////////////////////

  abstract Obj? run()

  protected Void openPin() { dispatch.openPin("$typeof") }

  protected Void closePin() { dispatch.closePin("$typeof") }

//////////////////////////////////////////////////////////////////////////
// Point Utils
//////////////////////////////////////////////////////////////////////////

  internal static NestTraitRef toCurId(ConnPoint pt) { toRemoteId(pt.rec, "nestCur") }
  internal static NestTraitRef toWriteId(ConnPoint pt) { toRemoteId(pt.rec, "nestWrite") }

  internal static NestTraitRef toRemoteId(Dict rec, Str tag)
  {
    val := rec[tag]
    if (val == null)   throw FaultErr("$tag not defined")
    if (val isnot Str) throw FaultErr("$tag must be a Str: $val.typeof.name")
    return NestTraitRef.fromStr(val)
  }
}

**************************************************************************
** NestTraitRef
**************************************************************************

internal const class NestTraitRef
{
  static new fromStr(Str s)
  {
    parts  := s.split(':')
    device := parts.first
    parts = parts.last.split('.')
    trait  := parts.first
    field  := parts.last
    return NestTraitRef(device, trait, field)
  }

  new make(Str deviceId, Str trait, Str field)
  {
    this.deviceId = deviceId
    this.trait = trait
    this.field = field
  }

  const Str deviceId
  const Str trait
  const Str field

  override Str toStr() { "${deviceId}:${trait}.${field}" }
}

