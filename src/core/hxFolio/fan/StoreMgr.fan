//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Feb 2016  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hxStore

**
** StoreMgr is responsible for writing record changes
** asynchronously to blob storage on a background actor
**
internal const class StoreMgr : HxFolioMgr
{

  new make(HxFolio folio, Loader loader)
    : super.makeCoalescing(folio, |Msg m->Obj?| { m.coalesceKey }, null)
  {
    this.blobs = loader.blobs

    // if in replica mode then put store into ro mode
    if (loader.config.isReplica)
      this.blobs.ro = true

    // on write IO error set into readonly mode to prevent corruption
    blobs.onWriteErr = |Err e|
    {
      blobs.ro = true
      log.err("Store I/O write error, locking down to readonly", e)
    }
  }

  const Store blobs

  Rec add(Dict tags) { send(Msg(MsgId.storeAdd, tags)).get(null) } // synchronous

  Void update(Rec rec) { send(Msg(MsgId.storeUpdate, rec)) }

  Void remove(Rec rec) { send(Msg(MsgId.storeRemove, rec)) }

  override Obj? onReceive(Msg msg)
  {
    try
    {
      switch (msg.id)
      {
        case MsgId.storeAdd:    return onAdd(msg.a)
        case MsgId.storeUpdate: return onUpdate(msg.a)
        case MsgId.storeRemove: return onRemove(msg.a)
        default:                return super.onReceive(msg)
      }
    }
    catch (Err e)
    {
      folio.log.err("Store error", e)
      throw e
    }
  }

  private Obj? onAdd(Dict persistent)
  {
    meta := Buf()
    data := encode(persistent)
    blob := blobs.create(meta, data)
    rec := Rec(blob, persistent)
    rec.numWritesRef.incrementAndGet
    return rec
  }

  private Obj? onUpdate(Rec rec)
  {
    data := encode(rec.persistent)
    rec.blob.write(null, data)
    rec.numWritesRef.incrementAndGet
    return rec
  }

  private Obj? onRemove(Rec rec)
  {
    rec.eachBlob |blob| { blob.delete }
    return rec
  }

  internal override Void onClose()
  {
    blobs.close
  }

  private Buf encode(Dict persistent)
  {
    buf := Actor.locals["buf"] as Buf
    if (buf == null) Actor.locals["buf"] = buf = Buf(1024)
    buf.clear
    brio := BrioWriter(buf.out)
    brio.encodeRefToRel = folio.idPrefix
    brio.encodeRefDis   = false
    brio.writeDict(persistent)
    return buf
  }

}

