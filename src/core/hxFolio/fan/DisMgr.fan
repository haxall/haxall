//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Dec 2013  Brian Frank  Creation
//    9 Nov 2015  Brian Frank  Port from ConcurrentCache
//

using concurrent
using haystack
using folio

**
** DisMgr is a responsible for updating the Ref.disVal of record
** ids when display string changes are detected
**
internal const class DisMgr : HxFolioMgr
{
  ** Construct with coalescing message queue
  new make(HxFolio folio)
    : super.makeCoalescing(folio, |Msg m->Obj?| { m.coalesceKey }, null)
  {
  }

  ** Asynchronously update all id dis values
  Future updateAll()
  {
    send(updateAllMsg)
  }

  ** Update one record
  Void update(Rec rec)
  {
    // short circuit if dis didn't change
    newDis := rec.dict.dis
    oldDis := rec.id.disVal
    if (oldDis == newDis) return

    // set immediately so calling thread sees the change
    setDis(rec, newDis)

    // kick off full update in background since this change
    // may ripple thru disMacro
    updateAll
  }

  ** Number of full updates done
  const AtomicInt updateAllCount := AtomicInt()

//////////////////////////////////////////////////////////////////////////
// Background Process
//////////////////////////////////////////////////////////////////////////

  override Obj? onReceive(Msg msg)
  {
    try
    {
      switch (msg.id)
      {
        case MsgId.disUpdateAll: return onUpdateAll()
        default:                 return super.onReceive(msg)
      }
    }
    catch (Err e)
    {
      log.err("DisMgr $msg.id", e)
      throw e
    }
  }

  private Obj? onUpdateAll()
  {
    updateAllCount.getAndIncrement
    cache := Ref:Str[:]
    folio.index.byId.each |Rec rec|
    {
      setDis(rec, toDis(cache, rec.id))
    }
    return "updateAll $cache.size"
  }

  internal Str toDis(Ref:Str cache, Ref id)
  {
    x := cache[id]
    if (x == null)
    {
      // stick default into cache in case recurse macro
      cache[id] = x = id.id

      // resolve actual display
      try
        cache[id] = x = computeDis(cache, id)
      catch (Err e)
        e.trace
    }
    return x
  }

  private Str computeDis(Ref:Str cache, Ref id)
  {
    // if we have disMacro, then use custom Macro, otherwise Dict.dis
    rec := folio.index.rec(id, false)
    if (rec != null)
    {
      dict := rec.dict
      disMacro := dict.get("disMacro", null) as Str
      return disMacro != null ?
             DisMgrMacro(disMacro, dict, this, cache).apply :
             dict.dis(null, null)
    }

    // use id itself
    return id.id
  }

  Void setDis(Rec rec, Str dis)
  {
    rec.id.disVal = dis
  }

  static const Msg updateAllMsg := Msg(MsgId.disUpdateAll)
}

**************************************************************************
** DisMgrMacro
**************************************************************************

internal class DisMgrMacro : Macro
{
  new make(Str p, Dict s, DisMgr m, Ref:Str c) : super(p, s) { mgr = m; cache = c }
  DisMgr mgr
  Ref:Str cache
  override Str refToDis(Ref ref) { mgr.toDis(cache, ref) }
}