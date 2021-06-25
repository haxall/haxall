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
internal const class HxdObserveMgr : Actor
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
    schedule = ScheduleObservable(); byName.add(schedule.name, schedule)
    commits = CommitsObservable(rt); byName.add(commits.name, commits)

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

  Observable[] list() { listRef.val }

  Observable? get(Str name, Bool checked := true)
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
// Schedule
//////////////////////////////////////////////////////////////////////////

  const ScheduleObservable schedule

//////////////////////////////////////////////////////////////////////////
// Commits
//////////////////////////////////////////////////////////////////////////

  const CommitsObservable commits

  Void sync(Duration? timeout)
  {
    send(HxMsg("sync")).get(timeout)
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
    CommitObservation.make(commits, action, rt.now, diff.id, oldRec, newRec, user?.meta)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const AtomicRef listRef
  private const ConcurrentMap byName  // Str:Observable
}

**************************************************************************
** CommitsObservable
**************************************************************************

internal const class CommitsObservable : Observable
{
  new make(HxRuntime rt) { this.rt  =rt }

  const HxRuntime rt

  override Str name() { "obsCommits" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    CommitsSubscription(this, observer, config)
  }
}

**************************************************************************
** CommitsSubscription
**************************************************************************

internal const class CommitsSubscription : Subscription
{
  new make(CommitsObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
    adds    = config.has("obsAdds")
    updates = config.has("obsUpdates")
    removes = config.has("obsRemoves")
    filter  = parseFilter(config["obsFilter"])

    if (!adds && !updates && !removes) throw Err("Must must define at least one: obsAdds, obsUpdates, or obsRemoves")
  }

  private static Filter? parseFilter(Obj? val)
  {
    if (val == null) return null
    if (val isnot Str) throw Err("obsFilter must be filter string")
    try
      return Filter.fromStr(val)
    catch (Err e)
      throw Err("obsFilter invalid: $e")
  }

  const Bool adds
  const Bool updates
  const Bool removes
  const Filter? filter

  Bool include(Dict rec)
  {
    if (rec.isEmpty) return false
    if (filter == null) return true
    return filter.matches(rec)
  }
}