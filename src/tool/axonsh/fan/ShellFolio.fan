//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Mar 2023  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio

**
** ShellFolio is a single-threaded in-memory implementation of Folio
**
const class ShellFolio : MemFolio
{
  new make(FolioConfig config) : super(config) {}

  override PasswordStore passwords() { throw UnsupportedErr() }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  override FolioFuture doCommitAllAsync(Diff[] diffs, Obj? cxInfo)
  {
    // normalize all the diffs - not thread-safe!!!
    newMod := DateTime.nowUtc(null)
    internedIds := Ref:Ref[:]
    diffs =  diffs.map |diff| { commitApply(diff, internedIds, newMod) }

    // walk thru each diff and update my concurrent map
    diffs.each |diff|
    {
      if (diff.isRemove)
        map.remove(diff.id)
      else
        map.set(diff.id, diff.newRec)
    }

    // force recompute of all dis on every commit; expensive but simple
    refreshDisAll

    return FolioFuture(CommitFolioRes(diffs))
  }

  private Diff commitApply(Diff diff, Ref:Ref internedIds, DateTime newMod)
  {
    // normalize and intern the id
    id := commitNorm(diff.id, internedIds)

    // lookup old record
    oldRec := map.get(id) as Dict

    // sanity check oldRec
    if (diff.isAdd)
    {
      if (oldRec != null) throw CommitErr("Rec already exists: $diff.id")
    }
    else
    {
      if (oldRec == null) throw CommitErr("Rec not found: $diff.id")
      if (!diff.isForce && oldRec->mod != diff.oldMod)
        throw ConcurrentChangeErr("$diff.id: ${oldRec->mod} != $diff.oldMod")
    }

    // construct new rec
    tags := Str:Obj[:]
    if (oldRec != null) oldRec.each |v, n| { tags[n] = v }
    diff.changes.each |v, n|
    {
      if (v === None.val) tags.remove(n)
      else tags[n] = commitNorm(v, internedIds)
    }
    tags["id"] = id
    if (!diff.isTransient) tags["mod"] = newMod
    newRec := Etc.dictFromMap(tags)
    newRec.id.disVal = newRec.dis

    // return applied Diff
    return Diff.makeAll(id, diff.oldMod, oldRec, newMod, newRec, diff.changes, diff.flags)
  }

  private Obj commitNorm(Obj val, Ref:Ref internedIds)
  {
    id := val as Ref
    if (id == null) return val

    interned := internedIds[id]
    if (interned != null) return interned

    rec := map.get(id) as Dict
    if (rec != null) return rec.id

    if (id.disVal != null) id = Ref(id.id, null)
    internedIds[id] = id
    return id
  }

//////////////////////////////////////////////////////////////////////////
// Ref Dis
//////////////////////////////////////////////////////////////////////////

  Void refreshDisAll()
  {
    // clear them all
    map.each |Dict rec| { rec.id.disVal = null }

    // update them all
    map.each |Dict rec| { refreshDis(rec) }
  }

  private Str refreshDis(Dict rec)
  {
    id := rec.id
    id.disVal = id.id // in case of circular macros
    disMacro := rec.get("disMacro") as Str
    dis := disMacro != null ?
           DisMacro(disMacro, rec, this).apply :
           rec.dis
    id.disVal = dis
    return dis
  }

  internal Str toDis(Ref id)
  {
    if (id.disVal != null) return id.disVal
    rec := map.get(id)
    if (rec == null) return id.id
    return refreshDis(rec)
  }

}

**************************************************************************
** DisMacro
**************************************************************************

internal class DisMacro : Macro
{
  new make(Str p, Dict s, ShellFolio db) : super(p, s) { this.db = db  }
  const ShellFolio db
  override Str refToDis(Ref ref) { db.toDis(ref) }
}

