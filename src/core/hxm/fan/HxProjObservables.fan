//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Apr 2020  Brian Frank  Creation
//   25 Jun 2021  Brian Frank  Refactor for Haxall
//   13 Jul 2025  Brian Frank  Refactor for 4.0
//

using concurrent
using xeto
using haystack
using obs
using folio
using hx

**
** Implementation for ProjWatches
**
const class HxProjObservables : Actor, ProjObservables
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(HxProj rt) : super(rt.hxdActorPool)
  {
    this.rt  = rt
    this.log = rt.db.log
    this.byName = ConcurrentMap()
    this.listRef = AtomicRef(null)

    // built-ins
    schedule  = ScheduleObservable();  byName.add(schedule.name,  schedule)
    commits   = CommitsObservable(rt); byName.add(commits.name,   commits)
    watches   = WatchesObservable(rt); byName.add(watches.name,   watches)
    curVals   = CurValsObservable();   byName.add(curVals.name,   curVals)
    hisWrites = HisWritesObservable(); byName.add(hisWrites.name, hisWrites)

    // finalize list for fast access
    listRef.val = Observable#.emptyList
    updateList
  }

  internal Void init()
  {
    // runtine lib observables
    rt.exts.list.each |lib| { addLib(lib) }
  }

//////////////////////////////////////////////////////////////////////////
// Lookup Tables
//////////////////////////////////////////////////////////////////////////

  const HxProj rt

  const Log log

  override Observable[] list() { listRef.val }

  override Observable? get(Str name, Bool checked := true)
  {
    o := byName.get(name)
    if (o != null) return o
    if (checked) throw UnknownObservableErr(name)
    return null
  }

  internal Void addLib(Ext lib)
  {
    try
    {
      list := lib.observables
      if (list.isEmpty) return
      if (lib.typeof.slot("observables") is Method) throw Err("${lib.typeof}.observables must be const field")
      list.each |o| { byName.add(o.name, o) }
      updateList
    }
    catch (Err e) log.err("${lib.typeof}.observables", e)
  }

  internal Void removeLib(Ext lib)
  {
    try
    {
      lib.observables.each |o|
      {
        o.unsubscribeAll
        byName.remove(o.name)
      }
      updateList
    }
    catch (Err e) log.err("${lib.typeof}.observables", e)
  }

  private Void updateList()
  {
    // skip this during initial load
    if (listRef.val == null) return

    Observable[] list := byName.vals(Observable#)
    list.sort |a, b| { a.name <=> b.name }
    list.moveTo(byName.get("observeSchedule"), 0)
    listRef.val = list.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Commits
//////////////////////////////////////////////////////////////////////////

  Void sync(Duration? timeout)
  {
    Future[] futures := send(HxMsg("sync")).get(timeout)
    Future.waitForAll(futures, timeout)
  }

  Void commit(Diff diff, HxUser? user)
  {
    if (commits.hasSubscriptions) send(HxMsg("commit", diff, user))
  }

  Void curVal(Diff diff)
  {
    if (curVals.hasSubscriptions) send(HxMsg("curVal", diff))
  }

  Void hisWrite(Dict rec, Dict result, HxUser? user)
  {
    if (hisWrites.hasSubscriptions) send(HxMsg("hisWrite", rec, result, user))
  }

  override Obj? receive(Obj? msgObj)
  {
    try
    {
      msg := (HxMsg)msgObj
      switch (msg.id)
      {
        case "commit":   return onCommit(msg.a, msg.b)
        case "curVal":   return onCurVal(msg.a)
        case "hisWrite": return onHisWrite(msg.a, msg.b, msg.c)
        case "sync":     return onSync
        default:         return null
      }
    }
    catch (Err e)
    {
      log.err("ObserveMgr", e)
      throw e
    }
  }

  private Obj? onCommit(Diff diff, HxUser? user)
  {
    oldRec := toDiffRec(diff.oldRec)
    newRec := toDiffRec(diff.newRec)
    commits.subscriptions.each |CommitsSubscription sub|
    {
      oldMatch := sub.include(oldRec)
      newMatch := sub.include(newRec)
      if (oldMatch)
      {
        if (newMatch)
          sendUpdated(sub, diff, oldRec, newRec, user)
        else
          sendRemoved(sub, diff, oldRec,  newRec, user)
      }
      else if (newMatch)
      {
        sendAdded(sub, diff, oldRec, newRec, user)
      }
    }
    return null
  }

  private static Dict toDiffRec(Dict? r)
  {
    if (r == null || r.has("trash"))
      return Etc.emptyDict
    else
      return r
  }

  private Void sendAdded(CommitsSubscription sub, Diff diff, Dict oldRec, Dict newRec, HxUser? user)
  {
    if (sub.adds) sub.send(toObservation(CommitObservationAction.added, diff, oldRec, newRec, user))
  }

  private Void sendUpdated(CommitsSubscription sub, Diff diff, Dict oldRec, Dict newRec, HxUser? user)
  {
    if (sub.updates) sub.send(toObservation(CommitObservationAction.updated, diff, oldRec, newRec, user))
  }

  private Void sendRemoved(CommitsSubscription sub, Diff diff, Dict oldRec, Dict newRec, HxUser? user)
  {
    if (sub.removes) sub.send(toObservation(CommitObservationAction.removed, diff, oldRec, newRec, user))
  }

  private Observation toObservation(CommitObservationAction action, Diff diff, Dict oldRec, Dict newRec, HxUser? user)
  {
    CommitObservation(commits, action, rt.now, diff.id, oldRec, newRec, user?.meta)
  }

  internal Void sendAddOnInit(CommitsSubscription sub)
  {
    rt.db.readAllEach(sub.filter, Etc.emptyDict) |rec|
    {
      event := CommitObservation(commits, CommitObservationAction.added, rt.now, rec.id, Etc.emptyDict, rec, null)
      sub.send(event)
    }
  }

  private Obj? onCurVal(Diff diff)
  {
    oldRec := toDiffRec(diff.oldRec)
    newRec := toDiffRec(diff.newRec)
    event  := CommitObservation(curVals, CommitObservationAction.updated, rt.now, diff.id, oldRec, newRec, null)
    curVals.subscriptions.each |CurValsSubscription sub|
    {
      if (sub.include(newRec)) sub.send(event)
    }
    return null
  }

  private Obj? onHisWrite(Dict rec, Dict result, HxUser? user)
  {
    count := result["count"] as Number
    span  := result["span"] as Span
    if (count == null || span == null)
    {
      log.warn("HxdObsService.onHisWrite invalid result: $result")
      return null
    }
    event := HisWriteObservation(hisWrites, rt.now, rec.id, rec, count, span, user?.meta)
    hisWrites.subscriptions.each |HisWritesSubscription sub|
    {
      if (sub.include(rec)) sub.send(event)
    }
    return null
  }

  private Obj? onSync()
  {
    // any subscriber which uses the marker tag "syncable" in its config
    // will be included in a runtime sync by sending it a null msg
    Subscription[] syncables := list.flatMap |obs->Subscription[]|
    {
      obs.subscriptions.findAll |sub| { sub.config.has("syncable") }
    }

    // short circuit if no syncables
    if (syncables.isEmpty) return Future#.emptyList

    // send sync message to all syncable observers and return Future[]
    return syncables.map |sub->Future| { sub.sync }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  override const ScheduleObservable schedule
  internal const CommitsObservable commits
  internal const WatchesObservable watches
  internal const CurValsObservable curVals
  internal const HisWritesObservable hisWrites

  private const AtomicRef listRef
  private const ConcurrentMap byName  // Str:Observable
}

**************************************************************************
** CommitsObservable
**************************************************************************

internal const class CommitsObservable : Observable
{
  new make(HxProj proj) { this.proj = proj }

  const HxProj proj

  override Str name() { "obsCommits" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    sub := CommitsSubscription(this, observer, config)
    if (sub.addOnInit) proj.obsRef.sendAddOnInit(sub)
    return sub
  }
}

**************************************************************************
** CommitsSubscription
**************************************************************************

internal const class CommitsSubscription : RecSubscription
{
  new make(CommitsObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
    adds      = config.has("obsAdds")
    updates   = config.has("obsUpdates")
    removes   = config.has("obsRemoves")
    addOnInit = config.has("obsAddOnInit")

    if (!adds && !updates && !removes) throw Err("Must must define at least one: obsAdds, obsUpdates, or obsRemoves")
    if (addOnInit && filter == null) throw Err("Must define obsFilter if using obsAddOnInit")
  }

  const Bool adds
  const Bool updates
  const Bool removes
  const Bool addOnInit
}

**************************************************************************
** WatchesObservable
**************************************************************************

internal const class WatchesObservable : Observable
{
  new make(HxProj rt) { this.rt = rt }

  const HxProj rt

  override Str name() { "obsWatches" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    sub := WatchesSubscription(this, observer, config)
    if (sub.filter != null)
    {
      // fire event for currently watched recs
      recs := rt.db.readAllList(sub.filter).findAll |rec| { rt.watch.isWatched(rec.id) }
      if (!recs.isEmpty)
        sub.send(makeObservation(DateTime.now, Etc.dict2("subType", "watch", "recs", recs)))
    }
    return sub
  }

  Void fireWatch(Dict[] recs) { fire("watch", recs) }

  Void fireUnwatch(Dict[] recs) { fire("unwatch", recs) }

  private Void fire(Str subType, Dict[] recs)
  {
    ts := DateTime.now
    subscriptions.each |WatchesSubscription sub|
    {
      matches := sub.filter == null ? recs : recs.findAll |rec| { sub.include(rec) }
      if (matches.isEmpty) return
      obs := makeObservation(ts, Etc.dict2("subType", subType, "recs", matches))
      sub.send(obs)
    }
    return null
  }
}

**************************************************************************
** WatchesSubscription
**************************************************************************

internal const class WatchesSubscription : RecSubscription
{
  new make(WatchesObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
  }
}

**************************************************************************
** CurValsObservable
**************************************************************************

internal const class CurValsObservable : Observable
{
  override Str name() { "obsCurVals" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    CurValsSubscription(this, observer, config)
  }
}

**************************************************************************
** CurValsSubscription
**************************************************************************

internal const class CurValsSubscription : RecSubscription
{
  new make(CurValsObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
  }
}

**************************************************************************
** HisWritesObservable
**************************************************************************

internal const class HisWritesObservable : Observable
{
  override Str name() { "obsHisWrites" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    HisWritesSubscription(this, observer, config)
  }
}

**************************************************************************
** HisWritesSubscription
**************************************************************************

internal const class HisWritesSubscription : RecSubscription
{
  new make(HisWritesObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
  }
}

