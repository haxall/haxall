//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Dec 2015  Brian Frank  Creation
//

using haystack
using concurrent

**
** FolioFlatFile is a simple `Folio` implementation backed by
** a [Trio]`docHaystack::Trio` flat file.
**
const class FolioFlatFile : Folio
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Open for given directory.  Create automatically if file not found.
  ** The database is stored in a file named "folio.trio" under dir.
  static FolioFlatFile open(FolioConfig config)
  {
    file := config.dir + `folio.trio`
    try
    {
      map := FolioFlatFileLoader(config, file).load
      return make(config, file, map)
    }
    catch (Err e) throw Err("Cannot open folio: $file", e)
  }

  private new make(FolioConfig config, File file, ConcurrentMap map)
    : super(config)
  {
    this.file = file
    this.map = map
    this.passwords = PasswordStore.open(dir+`passwords.props`, config)
    this.actor = Actor(config.pool) |msg| { onReceive(msg) }
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  @NoDoc const File file
  @NoDoc const override PasswordStore passwords
  private const Actor actor

  @NoDoc override Int curVer() { curVerRef.val }
  private const AtomicInt curVerRef := AtomicInt(1)

//////////////////////////////////////////////////////////////////////////
// Folio
//////////////////////////////////////////////////////////////////////////

  @NoDoc override Str flushMode
  {
    get { "fsync" }
    set { throw UnsupportedErr("flushMode") }
  }

  @NoDoc override Void flush() {}

  @NoDoc override FolioFuture doCloseAsync()
  {
    FolioFuture(CountFolioRes(0))
  }

  @NoDoc override FolioFuture doReadByIds(Ref[] ids)
  {
    map := this.map
    acc := Dict?[,]
    errMsg := ""
    dicts := Dict?[,]
    dicts.size = ids.size
    ids.each |id, i|
    {
      rec := map.get(id)
      if (rec == null && id.isRel && idPrefix != null)
        rec = map.get(id.toAbs(idPrefix))

      if (rec != null)
        dicts[i] = rec
      else if (errMsg.isEmpty)
        errMsg = id.toStr
    }
    errs := !errMsg.isEmpty
    return FolioFuture(ReadFolioRes(errMsg, errs, dicts))
  }

  @NoDoc override FolioFuture doReadAll(Filter filter, Dict? opts)
  {
    errMsg := filter.toStr
    acc := Dict[,]
    doReadAllEachWhile(filter, opts) |rec| { acc.add(rec); return null }
    return FolioFuture(ReadFolioRes(errMsg, false, acc))
  }

  @NoDoc override Int doReadCount(Filter filter, Dict? opts)
  {
    count := 0
    doReadAllEachWhile(filter, opts) |->| { count++ }
    return count
  }

  @NoDoc override Obj? doReadAllEachWhile(Filter filter, Dict? opts, |Dict->Obj?| f)
  {
    if (opts == null) opts = Etc.emptyDict
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

  @NoDoc override FolioFuture doCommitAllAsync(Diff[] diffs, Obj? cxInfo)
  {
    // check diffs on caller's thread
    diffs = diffs.toImmutable
    FolioUtil.checkDiffs(diffs)

    // send message to background actor
    return FolioFuture(actor.send(FolioFlatFileMsg("commit", diffs, cxInfo)))
  }

  @NoDoc override FolioHis his() { throw UnsupportedErr() }

  @NoDoc override FolioBackup backup() { throw UnsupportedErr() }

//////////////////////////////////////////////////////////////////////////
// ConcurrentHashMap
//////////////////////////////////////////////////////////////////////////

  internal const ConcurrentMap map

  private Obj? eachWhile(|Dict->Obj?| f) { map.eachWhile(f) }

  private Void each(|Dict| f) { map.each(f) }

//////////////////////////////////////////////////////////////////////////
// Actor Processing
//////////////////////////////////////////////////////////////////////////

  private Obj? onReceive(FolioFlatFileMsg msg)
  {
    switch (msg.id)
    {
      case "commit":  return onCommit(msg.a, msg.b)
      default:        throw Err("Invalid msg: $msg")
    }
  }

  private CommitFolioRes onCommit(Diff[] diffs, Obj? cxInfo)
  {
    // pre commit
    hooks := this.hooks
    diffs.each |diff| { hooks.preCommit(diff, cxInfo) }

    // map diffs to commit handlers
    newMod := DateTime.nowUtc(null)
    commits := FolioFlatFileCommit[,]
    diffs.each |diff| { commits.add(FolioFlatFileCommit(this, diff, newMod)) }

    // verify all commits upfront
    commits.each |c| { c.verify }

    // apply to compute new record Dict
    diffs = commits.map |c->Diff| { c.apply }

    // update in-memory copy
    map := this.map
    diffs.each |diff|
    {
      if (diff.isRemove)
        map.remove(diff.id)
      else
        map.set(diff.id, diff.newRec)
    }

    // post commit
    diffs.each |diff| { hooks.postCommit(diff, cxInfo) }

    // save to file
    if (!diffs.first.isTransient)
    {
      curVerRef.increment
      saveToFile
    }

    // return result diffs
    return CommitFolioRes(diffs)
  }

  private Void saveToFile()
  {
    // get all dicts as a list
    recs := (Dict[])map.vals(Dict#)

    // flush to file
    out := file.out
    FolioFlatFileWriter(this, out).writeAllDicts(recs)
    out.sync.close
  }
}

**************************************************************************
** FolioFlatFileMsg
**************************************************************************

internal const class FolioFlatFileMsg
{
  new make(Str id, Obj? a, Obj? b) { this.id = id; this.a = a; this.b = b }
  const Str id
  const Obj? a
  const Obj? b
}

**************************************************************************
** FolioFlatFileLoader
**************************************************************************

internal class FolioFlatFileLoader
{
  new make(FolioConfig config, File file)
  {
    this.idPrefix = config.idPrefix
    this.file = file
  }

  ConcurrentMap load()
  {
    readTrio
    normIds
    normRecs
    updateDisVal
    return makeMap
  }

  private Void readTrio()
  {
    if (!file.exists) return
    recs = TrioReader(file.in).readAllDicts
  }

  private Void normIds()
  {
    recs.each |rec|
    {
      id := normRef(rec.id)
      ids.add(id)
      idsMap.add(id, id)
    }
  }

  private Ref normRef(Ref id)
  {
    if (id.isRel && idPrefix != null) id = id.toAbs(idPrefix)
    intern := idsMap[id]
    if (intern != null) return intern
    return id
  }

  private Void normRecs()
  {
    recs = recs.map |rec->Dict| { normRec(rec) }
  }

  private Dict normRec(Dict rec)
  {
    tags := Str:Obj[:]
    rec.each |v, n|
    {
      if (v is Ref) v = normRef(v)
      tags[n] = v
    }
    return Etc.makeDict(tags)
  }

  private Void updateDisVal()
  {
    recs.each |rec|
    {
      rec.id.disVal = rec.dis
    }
  }

  private ConcurrentMap makeMap()
  {
    map := ConcurrentMap(1024)
    recs.each |rec|
    {
      id := rec.id
      if (map.get(id) != null) throw Err("Duplicate ids: $id")
      map.set(id, rec)
    }
    return map
  }

  const Str? idPrefix
  const File file
  Dict[] recs := [,]
  Ref[] ids := [,]
  Ref:Ref idsMap := [:]
}

**************************************************************************
** FolioFlatFileWriter
**************************************************************************

internal class FolioFlatFileWriter : TrioWriter
{
  new make(FolioFlatFile f, OutStream out) : super(out) { folio = f }

  const FolioFlatFile folio

  override Obj normVal(Obj val)
  {
    if (val is Ref) return normRef(val)
    return val
  }

  Ref normRef(Ref id)
  {
    id = id.toRel(folio.idPrefix)
    if (id.disVal == null) return id
    return Ref(id, null)
  }
}

**************************************************************************
** FolioFlatFileCommit
**************************************************************************

internal class FolioFlatFileCommit
{
  new make(FolioFlatFile folio, Diff diff, DateTime newMod)
  {
    this.folio  = folio
    this.id     = normRef(diff.id)
    this.inDiff = diff
    this.newMod = newMod
    this.oldRec = folio.map.get(this.id)
    this.oldMod = inDiff.oldMod
  }

  const FolioFlatFile folio
  const Ref id
  const Diff inDiff
  const DateTime newMod
  const Dict? oldRec
  const DateTime? oldMod

  Void verify()
  {
    // sanity check oldRec
    if (inDiff.isAdd)
    {
      if (oldRec != null) throw CommitErr("Rec already exists: $id")
    }
    else
    {
      if (oldRec == null) throw CommitErr("Rec not found: $id")

      // unless the force flag was specified check for
      // concurrent change errors
      if (!inDiff.isForce && oldRec->mod != oldMod)
        throw ConcurrentChangeErr("$id: ${oldRec->mod} != $oldMod")
    }
    return this
  }

  Diff apply()
  {
    // construct new rec
    tags := Str:Obj[:]
    if (oldRec != null) oldRec.each |v, n| { tags[n] = v }
    inDiff.changes.each |v, n|
    {
      if (v === Remove.val) tags.remove(n)
      else tags[n] = norm(v)
    }
    tags["id"] = id
    if (!inDiff.isTransient) tags["mod"] = this.newMod
    newRec := Etc.makeDict(tags)
    newRec.id.disVal = newRec.dis

    // return applied Diff
    return Diff.makeAll(id, oldMod, oldRec, newMod, newRec, inDiff.changes, inDiff.flags)
  }

  private Obj norm(Obj val)
  {
    if (val is Ref) return normRef(val)
    return val
  }

  private Ref normRef(Ref id)
  {
    if (id.isRel && folio.idPrefix != null) id = id.toAbs(folio.idPrefix)
    rec := folio.map.get(id) as Dict
    if (rec != null) return rec.id
    if (id.disVal != null) id = Ref(id.id, null)
    return id
  }
}


