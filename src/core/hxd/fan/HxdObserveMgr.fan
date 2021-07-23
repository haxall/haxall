//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Apr 2020  Brian Frank  Creation
//   25 Jun 2021  Brian Frank  Refactor for Haxall
//

using concurrent
using haystack
using obs
using folio
using hx

**
** HxdObserveMgr
**
const class HxdObserveMgr : Actor, HxRuntimeObs
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(HxdRuntime rt) : super(rt.hxdActorPool)
  {
    this.rt  = rt
    this.log = rt.db.log
    this.byName = ConcurrentMap()
    this.listRef = AtomicRef(null)

    // built-ins
    schedule = ScheduleObservable();  byName.add(schedule.name, schedule)
    commits  = CommitsObservable(rt); byName.add(commits.name, commits)
    watch    = WatchObservable(rt);   byName.add(watch.name, watch)

    // runtine lib observables
    rt.libs.list.each |lib| { addLib(lib) }

    // finalize list for fast access
    listRef.val = Observable#.emptyList
    updateList
  }

//////////////////////////////////////////////////////////////////////////
// Lookup Tables
//////////////////////////////////////////////////////////////////////////

  const HxdRuntime rt

  const Log log

  override Observable[] list() { listRef.val }

  override Observable? get(Str name, Bool checked := true)
  {
    o := byName.get(name)
    if (o != null) return o
    if (checked) throw UnknownObservableErr(name)
    return null
  }

  internal Void addLib(HxLib lib)
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

  internal Void removeLib(HxLib lib)
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
    if (diff.isTransient) return
    if (commits.hasSubscriptions) send(HxMsg("diff", diff, user))
  }

  override Obj? receive(Obj? msgObj)
  {
    try
    {
      msg := (HxMsg)msgObj
      switch (msg.id)
      {
        case "diff": return onDiff(msg.a, msg.b)
        case "sync": return onSync
        default:     return null
      }
    }
    catch (Err e)
    {
      log.err("ObserveMgr", e)
      throw e
    }
  }

  private Obj? onDiff(Diff diff, HxUser? user)
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

    // send null message to all syncable observers and return Future[]
    return syncables.map |sub->Future| { sub.observer.actor.send(null) }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  internal const ScheduleObservable schedule
  internal const CommitsObservable commits
  internal const WatchObservable watch

  private const AtomicRef listRef
  private const ConcurrentMap byName  // Str:Observable
}

**************************************************************************
** CommitsObservable
**************************************************************************

internal const class CommitsObservable : Observable
{
  new make(HxdRuntime rt) { this.rt = rt }

  const HxdRuntime rt

  override Str name() { "obsCommits" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    sub := CommitsSubscription(this, observer, config)
    if (sub.addOnInit) rt.obs.sendAddOnInit(sub)
    return sub
  }
}

**************************************************************************
** CommitsSubscription
**************************************************************************

internal const class CommitsSubscription : FilterSubscription
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
** WatchObservable
**************************************************************************

internal const class WatchObservable : Observable
{
  new make(HxdRuntime rt) { this.rt = rt }

  const HxdRuntime rt

  override Str name() { "obsWatch" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    WatchSubscription(this, observer, config)
  }

  Void fireWatch(Dict[] recs) { fire("watch", recs) }

  Void fireUnwatch(Dict[] recs) { fire("unwatch", recs) }

  private Void fire(Str subType, Dict[] recs)
  {
    ts := DateTime.now
    subscriptions.each |WatchSubscription sub|
    {
      matches := sub.filter == null ? recs : recs.findAll |rec| { sub.include(rec) }
      if (matches.isEmpty) return
      obs := makeObservation(ts, Etc.makeDict2("subType", subType, "recs", matches))
      sub.send(obs)
    }
    return null
  }
}

**************************************************************************
** WatchSubscription
**************************************************************************

internal const class WatchSubscription : FilterSubscription
{
  new make(WatchObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
  }
}