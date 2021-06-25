//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Apr 2020  Brian Frank  Creation (lockdown!)
//

using concurrent
using haystack
using folio
using obs
using hx

**
** ObserveTest
**
class ObserveTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testBasics()
  {
    // built-in only
    verifyObservable("obsCommits")
    verifyObservable("obsSchedule")
    verifyNotObservable("obsFoo")

    // add lib
    rt.libs.add("hxTestA")
    os := verifyObservable("obsSchedule")
    oc := verifyObservable("obsCommits")
    ox := verifyObservable("obsTest")

    // setup observer
    sc := subscribe(oc, ["obsAdds":m])
    ss := subscribe(os, ["obsScheduleFreq":n(10, "sec")])
    sx:= subscribe(ox, null)

    // remove lib
    rt.libs.remove("hxTestA")
    verifyObservable("obsCommits")
    verifyObservable("obsSchedule")
    verifyNotObservable("obsTest")

    // verify subscription automatically cancelled
    verifySubscribed(oc, sc)
    verifySubscribed(os, ss)
    verifyUnsubscribed(ox, sx)
  }

  private Observable verifyObservable(Str name)
  {
    o := rt.observable(name)
    verifyEq(o.name, name)
    verifyEq(rt.observables.containsSame(o), true)
    return o
  }

  private Void verifyNotObservable(Str name)
  {
    verifyEq(rt.observable(name, false), null)
    verifyErr(UnknownObservableErr#) { rt.observable(name) }
    verifyErr(UnknownObservableErr#) { rt.observable(name, true) }
    verifyEq(rt.observables.find |o| { o.name == name }, null)
  }

  private Subscription subscribe(Observable o, Obj? configObj)
  {
    config := Etc.makeDict(configObj)

    oldSize := o.subscriptions.size
    dummy := TestObserver()
    s := o.subscribe(dummy, config)

    verifySame(s.observable, o)
    verifySame(s.observer, dummy)
    verifySame(s.observer.actor, dummy)
    verifySame(s.config, config)
    verifyEq(o.subscriptions.size, oldSize+1)
    verifySubscribed(o, s)
    return s
  }

  private Void verifySubscribed(Observable o, Subscription s)
  {
    verifySame(s.observable, o)
    verifyEq(s.isSubscribed, true)
    verifyEq(s.isUnsubscribed, false)
    verifyEq(o.subscriptions.containsSame(s), true)
  }

  private Void verifyUnsubscribed(Observable o, Subscription s)
  {
    verifySame(s.observable, o)
    verifyEq(s.isSubscribed, false)
    verifyEq(s.isUnsubscribed, true)
    verifyEq(o.subscriptions.containsSame(s), false)
  }

//////////////////////////////////////////////////////////////////////////
// Schedule
//////////////////////////////////////////////////////////////////////////

  Void testSchedule()
  {
    now := DateTime.now

    // obsScheduleSpan
    s := sched(["obsScheduleFreq":n(10, "sec"), "obsScheduleSpan":Span.today])
    verifyEq(s.span, Span.today)
    verifyActive(s, now, true)
    verifyActive(s, now-24hr, false)
    verifyActive(s, now+24hr, false)

    // obsScheduleDaysOfWeek
    s = sched(["obsScheduleFreq":n(10, "sec"), "obsScheduleDaysOfWeek":"fri,mon"])
    verifyEq(s.daysOfWeek, [Weekday.mon, Weekday.fri])
    verifyActive(s, "2020-04-12", false) // sun
    verifyActive(s, "2020-04-13", true)  // mon
    verifyActive(s, "2020-04-14", false) // tue
    verifyActive(s, "2020-04-15", false) // wed
    verifyActive(s, "2020-04-16", false) // thu
    verifyActive(s, "2020-04-17", true)  // fri
    verifyActive(s, "2020-04-18", false) // sat

    // obsScheduleDaysOfMonth
    s = sched(["obsScheduleFreq":n(10, "sec"), "obsScheduleDaysOfMonth":"3,15,-1,-3"])
    verifyEq(s.daysOfMonth, [-3, -1, 3, 15])
    verifyActive(s, "2020-04-02", false)
    verifyActive(s, "2020-04-03", true)
    verifyActive(s, "2020-04-04", false)
    verifyActive(s, "2020-04-14", false)
    verifyActive(s, "2020-04-15", true)
    verifyActive(s, "2020-04-16", false)
    verifyActive(s, "2020-04-28", true)
    verifyActive(s, "2020-04-29", false)
    verifyActive(s, "2020-04-30", true)
    verifyActive(s, "2020-02-27", true)
    verifyActive(s, "2020-02-28", false)
    verifyActive(s, "2020-02-29", true)

    // errors
    verifySchedErr(["obsScheduleFreq":"bad"], "obsScheduleFreq must be duration")
    verifySchedErr(["obsScheduleFreq":n(10)], "obsScheduleFreq must be duration")
    verifySchedErr(["obsScheduleFreq":n(0, "sec")], "obsScheduleFreq cannot be less than 1sec")
    verifySchedErr(["obsScheduleFreq":n(100, "ms")], "obsScheduleFreq cannot be less than 1sec")

    verifySchedErr(["obsScheduleTimes":"bad"], "obsScheduleTimes must be list of times")
    verifySchedErr(["obsScheduleTimes":["xx"]], "obsScheduleTimes must be list of times")

    verifySchedErr(["obsScheduleSpan":"bad"], "obsScheduleSpan must be Span")

    verifySchedErr(["obsScheduleDaysOfMonth":"bad"], "obsScheduleDaysOfMonth must be comma separated list of integers")
    verifySchedErr(["obsScheduleDaysOfMonth":"2.4"], "obsScheduleDaysOfMonth must be comma separated list of integers")
    verifySchedErr(["obsScheduleDaysOfMonth":"32"], "obsScheduleDaysOfMonth invalid day: 32")

    verifySchedErr(["obsScheduleDaysOfWeek":"bad"], "obsScheduleDaysOfWeek must be comma separated list of weekdays")
    verifySchedErr(["obsScheduleDaysOfWeek":"sun,bad"], "obsScheduleDaysOfWeek must be comma separated list of weekdays")

    verifySchedErr(null, "Must define either obsScheduleFreq or obsScheduleTimes")
    verifySchedErr(["obsScheduleFreq":n(10, "sec"), "obsScheduleTimes":[Time.defVal]], "Cannot define both obsScheduleFreq and obsScheduleTimes")
  }

  private Void verifySchedErr(Obj? config, Str msg)
  {
    verifyErrMsg(Err#, msg) { sched(config) }
  }

  private ScheduleSubscription sched(Obj? config)
  {
    ScheduleObservable().subscribe(TestObserver(), Etc.makeDict(config))
  }

  private Void verifyActive(ScheduleSubscription s, Obj ts, Bool expected)
  {
    if (ts is Str) ts = Date.fromStr(ts).midnight
    actual := s.isActive(ts)
    // echo("-- $s.configDebug $expected ?= $actual [${ts->toLocale}]")
    verifyEq(expected, actual)
  }

//////////////////////////////////////////////////////////////////////////
// Commits
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testCommits()
  {
    doTestCommits
    cx := makeContext
    Actor.locals[Etc.cxActorLocalsKey] = cx
    try
      doTestCommits
    finally
      Actor.locals.remove(Etc.cxActorLocalsKey)
  }

  private Void doTestCommits()
  {
    empty := Etc.emptyDict

    // all records
    all := TestObserver()
    commits(all, ["obsAdds":m, "obsUpdates":m, "obsRemoves":m])

    // foo records
    foo := TestObserver()
    commits(foo, ["obsAdds":m, "obsUpdates":m, "obsRemoves":m, "obsFilter":"foo"])

    // add record
    a1 := addRec(["dis":"a"])
    verifyCommit(all, ["subType": "added", "id": a1.id, "oldRec":empty, "newRec":a1])
    verifyCommit(foo, null)

    // add foo the existing record
    a2 := commit(a1, ["foo":m])
    verifyCommit(all, ["subType": "updated", "id": a1.id, "oldRec":a1, "newRec":a2])
    verifyCommit(foo, ["subType": "added", "id": a1.id, "oldRec":a1, "newRec":a2])

    // add trash tag
    a3 := commit(a2, ["trash":m])
    verifyCommit(all, ["subType": "removed", "id": a1.id, "oldRec":a2, "newRec":empty])
    verifyCommit(foo, ["subType": "removed", "id": a1.id, "oldRec":a2, "newRec":empty])

    // remove trash tag
    a4 := commit(a3, ["trash":Remove.val])
    verifyCommit(all, ["subType": "added", "id": a1.id, "oldRec":empty, "newRec":a4])
    verifyCommit(foo, ["subType": "added", "id": a1.id, "oldRec":empty, "newRec":a4])

    // remove foo tag
    a5 := commit(a4, ["foo":Remove.val])
    verifyCommit(all, ["subType": "updated", "id": a1.id, "oldRec":a4, "newRec":a5])
    verifyCommit(foo, ["subType": "removed", "id": a1.id, "oldRec":a4, "newRec":a5])

    // remove record
    commit(a5, null, Diff.remove)
    verifyCommit(all, ["subType": "removed", "id": a1.id, "oldRec":a5, "newRec":empty])
    verifyCommit(foo, null)

    // errors
    verifyCommitsErr([:], "Must must define at least one: obsAdds, obsUpdates, or obsRemoves")
    verifyCommitsErr(["obsFilter":n(123)], "obsFilter must be filter string")
    verifyCommitsErr(["obsFilter":"#foo"], "obsFilter invalid: sys::ParseErr: Unexpected symbol: '#' (0x23) [line 1]")
  }

  private Void verifyCommit(TestObserver o, Obj? expected)
  {
    rt.sync
    actual := o.sync
    // echo("-- verifyCommit"); if (actual != null) Etc.dictDump(actual)
    if (expected == null)
    {
      verifyEq(actual, null)
    }
    else
    {
      expected = Etc.makeDict(expected)
      expected = Etc.dictSet(expected, "type", "obsCommits")
      expected = Etc.dictSet(expected, "ts", actual->ts)

      cx := HxContext.curHx(false)
      if (cx != null)
        expected = Etc.dictSet(expected, "user", cx.user.meta)

      verifyEq(actual->subType, expected->subType)
      verifyDictEq(actual, expected)

      c := (CommitObservation)actual
      verifyEq(c.type, "obsCommits")
      verifyEq(c.subType, expected->subType)
      verifySame(c.action, CommitObservationAction.fromStr(c.subType))
    }
    o.clear
  }

  private Void verifyCommitsErr(Obj? config, Str msg)
  {
    verifyErrMsg(Err#, msg) { commits(TestObserver(), config) }
  }

  private Subscription commits(TestObserver o, Obj? config)
  {
    rt.observable("obsCommits").subscribe(o, Etc.makeDict(config))
  }

}

**************************************************************************
** TestObservable
**************************************************************************

internal const class TestObservable : Observable
{
  override Str name() { "obsTest" }
}

**************************************************************************
** TestObserver
**************************************************************************

internal const class TestObserver : Actor, Observer
{
  new make() : super(ActorPool()) {}
  override Dict meta() { Etc.emptyDict }
  override Actor actor() { this }
  override Obj? receive(Obj? msg)
  {
    if (msg == "_sync_") return msgs.last
    msgsRef.val = msgs.dup.add(msg).toImmutable
    return null
  }
  Obj? sync() { send("_sync_").get }
  Obj[] msgs() { msgsRef.val }
  Void clear() { msgsRef.val = Obj#.emptyList }
  const AtomicRef msgsRef := AtomicRef(Obj#.emptyList)
}