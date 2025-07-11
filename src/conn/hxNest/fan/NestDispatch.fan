//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jan 2022  Matthew Giannini  Creation
//

using xeto
using haystack
using hx
using hxConn

class NestDispatch : ConnDispatch
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Obj arg) : super(arg) {}

  private NestLib nestLib() { ext }

  internal Nest? client

//////////////////////////////////////////////////////////////////////////
//  Open/Ping/Close
//////////////////////////////////////////////////////////////////////////

  override Void onOpen()
  {
    this.client = Nest(
      rec->nestProjectId,
      password("nestClientId"),
      password("nestClientSecret"),
      password("nestRefreshToken"),
      trace.asLog
    )
  }

  private Str password(Str name)
  {
    db.passwords.get("$id $name") ?: throw FaultErr("Missing password for $name")
  }

  override Void onClose()
  {
    this.client = null
  }

  override Dict onPing()
  {
    structures := client.structures.list
    return Etc.emptyDict()
  }

//////////////////////////////////////////////////////////////////////////
// Points
//////////////////////////////////////////////////////////////////////////

  override Void onSyncCur(ConnPoint[] points)
  {
    NestSyncCur(this, points).run
  }

  override Void onWrite(ConnPoint point, ConnWriteInfo event)
  {
    NestWrite(this, point, event).run
  }

//////////////////////////////////////////////////////////////////////////
// Learn
//////////////////////////////////////////////////////////////////////////

  override Grid onLearn(Obj? arg)
  {
    NestLearn(this, arg).run
  }
}

