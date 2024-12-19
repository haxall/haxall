//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Mar 2023  Brian Frank  Creation
//

using concurrent
using haystack
using folio

**
** ShellFolio is a single-threaded in-memory implementation of Folio
**
const class ShellFolio : Folio
{
  new make(FolioConfig config) : super(config) {}

  override PasswordStore passwords() { throw UnsupportedErr() }

  override Int curVer() { curVerRef.val }
  private const AtomicInt curVerRef := AtomicInt(1)

  override Str flushMode
  {
    get { "fsync" }
    set { throw UnsupportedErr() }
  }

  override Void flush() {}

  override FolioFuture doCloseAsync()
  {
    FolioFuture(CountFolioRes(0))
  }

  override FolioFuture doReadByIds(Ref[] ids)
  {
    map := this.map
    acc := Dict?[,]
    errMsg := ""
    dicts := Dict?[,]
    dicts.size = ids.size
    ids.each |id, i|
    {
      rec := map.get(id)
      if (rec != null)
        dicts[i] = rec
      else if (errMsg.isEmpty)
        errMsg = id.toStr
    }
    errs := !errMsg.isEmpty
    return FolioFuture(ReadFolioRes(errMsg, errs, dicts))
  }

  override FolioFuture doReadAll(Filter filter, Dict? opts)
  {
    errMsg := filter.toStr
    acc := Dict[,]
    doReadAllEachWhile(filter, opts) |rec| { acc.add(rec); return null }
    if (opts != null && opts.has("sort")) acc = Etc.sortDictsByDis(acc)
    return FolioFuture(ReadFolioRes(errMsg, false, acc))
  }

  override Int doReadCount(Filter filter, Dict? opts)
  {
    count := 0
    doReadAllEachWhile(filter, opts) |->| { count++ }
    return count
  }

  override Obj? doReadAllEachWhile(Filter filter, Dict? opts, |Dict->Obj?| f)
  {
    if (opts == null) opts = Etc.dict0
    limit := (opts["limit"] as Number)?.toInt ?: 10_000
    skipTrash := opts.missing("trash")

    map := this.map
    cx := PatherContext(|Ref id->Dict?| { map.get(id) })

    count := 0
    return eachWhile |rec|
    {
      if (!filter.matches(rec, cx)) return null
      if (rec.has("trash") && skipTrash) return null
      count++
      x := f(rec)
      if (x != null) return x
      return count >= limit ? "break" : null
    }
  }

  override FolioHis his() { throw UnsupportedErr() }

  override FolioBackup backup() { throw UnsupportedErr() }

  override FolioFile file() { throw UnsupportedErr() }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  override FolioFuture doCommitAllAsync(Diff[] diffs, Obj? cxInfo)
  {
    // check and normalize all the diffs - not thread-safe!!!
    FolioUtil.checkDiffs(diffs)
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
      if (v === Remove.val) tags.remove(n)
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
    disMacro := rec.get("disMacro", null) as Str
    dis := disMacro != null ?
           DisMacro(disMacro, rec, this).apply :
           rec.dis(null, null)
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

//////////////////////////////////////////////////////////////////////////
// Rec Map
//////////////////////////////////////////////////////////////////////////

  private Obj? eachWhile(|Dict->Obj?| f) { map.eachWhile(f) }

  private Void each(|Dict| f) { map.each(f) }

  private const ConcurrentMap map := ConcurrentMap()

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