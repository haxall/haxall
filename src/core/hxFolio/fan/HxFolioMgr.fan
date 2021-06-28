//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Feb 2016  Brian Frank  Creation
//

using concurrent
using haystack
using folio

**
** HxFolioMgr is the abstract base class for an actor sub-systems
**
@NoDoc abstract const class HxFolioMgr : Actor
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(HxFolio folio) : super(folio.config.pool)
  {
    this.folio = folio
  }

  new makeCoalescing(HxFolio folio,
      |Obj? msg -> Obj?|? toKey,
      |Obj? orig, Obj? incoming -> Obj?|? coalesce)
    : super(folio.config.pool, toKey, coalesce)
  {
    this.folio = folio
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  const HxFolio folio

  Log log() { folio.log }

//////////////////////////////////////////////////////////////////////////
// Actor Support
//////////////////////////////////////////////////////////////////////////

  Void sync(Duration? timeout := 30sec)
  {
    send(Msg(MsgId.sync)).get(timeout)
  }

  override final Obj? receive(Obj? msg) { onReceive(msg) }

  virtual internal Obj? onReceive(Msg msg)
  {
    switch (msg.id)
    {
      case MsgId.sync:      return "sync"
      case MsgId.close:     onClose; return CountFolioRes(0)
      case MsgId.testSleep: Actor.sleep(msg.a); return null
    }
    log.err("$typeof unknown msg: $msg" )
    throw Err("Unknown msg: $msg.id")
  }

  internal virtual Void onClose() {}

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  virtual Void debugDump(OutStream out)
  {
    this->dump(out) // Actor details
  }

}

**************************************************************************
** Msg
**************************************************************************

internal const class Msg
{
  new make(MsgId id, Obj? a := null, Obj? b := null, Obj? c := null, Obj? d := null)
  {
    this.id = id
    this.a  = a
    this.b  = b
    this.c  = c
    this.d = d

    // if id is flagged as coalescing, then create key
    // based on id and assumption that a is null or Rec
    if (id.coalesce) this.coalesceKey = MsgCoalesceKey(id, a)
  }

  const MsgId id
  const Obj? a
  const Obj? b
  const Obj? c
  const Obj? d
  const MsgCoalesceKey? coalesceKey

  override Str toStr() { Etc.debugMsg("Msg", id, a, b, c, d) }
}

**************************************************************************
** MsgId
**************************************************************************

internal enum class MsgId
{
  sync,
  testSleep,
  close,
  commit,
  updateHis,
  storeAdd,
  storeUpdate(true),
  storeRemove,
  disUpdateAll(true),
  disUpdate,
  hisWrite

  private new make(Bool coalesce := false)
  {
    this.coalesce = coalesce
  }

  const Bool coalesce
}

**************************************************************************
** MsgCoalesceKey
**************************************************************************

internal const class MsgCoalesceKey
{
  new make(MsgId id, Rec? rec)
  {
    this.hash = rec == null ? id.hash : id.hash.xor(rec.id.hash)
    this.id   = id
    this.rec  = rec
  }

  const override Int hash
  const MsgId id
  const Rec? rec

  override Bool equals(Obj? obj)
  {
    that := (MsgCoalesceKey)obj
    return this.id === that.id && this.rec === that.rec
  }

  override Str toStr() { "$id $rec.id" }

}




