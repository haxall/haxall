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
internal const class ShellFolio : Folio
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

  override FolioFuture doCommitAllAsync(Diff[] diffs, Obj? cxInfo)
  {
    FolioUtil.checkDiffs(diffs)

    newMod := DateTime.nowUtc(null)
    diffs =  diffs.map |diff| { commitApply(diff, newMod) }

    diffs.each |diff|
    {
      if (diff.isRemove)
        map.remove(diff.id)
      else
        map.set(diff.id, diff.newRec)
    }

    return FolioFuture(CommitFolioRes(diffs))
  }

  private Diff commitApply(Diff diff, DateTime newMod)
  {
    id := diff.id
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
      else tags[n] = commitNorm(v)
    }
    tags["id"] = id
    if (!diff.isTransient) tags["mod"] = newMod
    newRec := Etc.dictFromMap(tags)
    newRec.id.disVal = newRec.dis

    // return applied Diff
    return Diff.makeAll(id, diff.oldMod, oldRec, newMod, newRec, diff.changes, diff.flags)
  }

  private Obj commitNorm(Obj val)
  {
    id := val as Ref
    if (id == null) return val
    rec := map.get(id) as Dict
    if (rec != null) return rec.id
    if (id.disVal != null) id = Ref(id.id, null)
    return id
  }

  override FolioHis his() { throw UnsupportedErr() }

  override FolioBackup backup() { throw UnsupportedErr() }

  private Obj? eachWhile(|Dict->Obj?| f) { map.eachWhile(f) }

  private Void each(|Dict| f) { map.each(f) }

  private const ConcurrentMap map := ConcurrentMap()

}

