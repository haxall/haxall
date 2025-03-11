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
    o := rt.obs.get(name)
    verifyEq(o.name, name)
    verifyEq(rt.obs.list.containsSame(o), true)
    return o
  }

  private Void verifyNotObservable(Str name)
  {
    verifyEq(rt.obs.get(name, false), null)
    verifyErr(UnknownObservableErr#) { rt.obs.get(name) }
    verifyErr(UnknownObservableErr#) { rt.obs.get(name, true) }
    verifyEq(rt.obs.list.find |o| { o.name == name }, null)
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
    Actor.locals[ActorContext.actorLocalsKey] = cx
    try
      doTestCommits
    finally
      Actor.locals.remove(ActorContext.actorLocalsKey)
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

    // update a transiently
    a1 = commit(a1, ["curVal":n(123)], Diff.transient)
    verifyCommit(all, null)
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

    // add some bars and listen with obsAddOnInit
    b1 := addRec(["dis":"B1", "bar":Marker.val])
    b2 := addRec(["dis":"B2", "bar":Marker.val])
    b3 := addRec(["dis":"B3", "bar":Marker.val])
    rt.sync
    bar := TestObserver()
    commits(bar, ["obsAdds":m, "obsUpdates":m, "obsRemoves":m, "obsFilter":"bar", "obsAddOnInit":m])
    rt.sync
    bar.sync
    msgs := (Dict[])bar.msgs.dup.sort |Dict a, Dict b->Int| { a.dis <=> b.dis }
    verifyEq(msgs.size, 3)
    verifyDictEq(msgs[0], commitExpected(msgs[0], ["subType": "added", "id": b1.id, "oldRec":empty, "newRec":b1]))
    verifyDictEq(msgs[1], commitExpected(msgs[1], ["subType": "added", "id": b2.id, "oldRec":empty, "newRec":b2]))
    verifyDictEq(msgs[2], commitExpected(msgs[2], ["subType": "added", "id": b3.id, "oldRec":empty, "newRec":b3]))
    commit(b1, null, Diff.remove)
    commit(b2, null, Diff.remove)
    commit(b3, null, Diff.remove)

    // errors
    verifyCommitsErr([:], "Must must define at least one: obsAdds, obsUpdates, or obsRemoves")
    verifyCommitsErr(["obsAdds":m, "obsAddOnInit":m], "Must define obsFilter if using obsAddOnInit")
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
      expected = commitExpected(actual, expected)

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

  private Dict commitExpected(Dict actual, Obj? expected)
  {
    expected = Etc.makeDict(expected)
    expected = Etc.dictSet(expected, "type", "obsCommits")
    expected = Etc.dictSet(expected, "ts", actual->ts)

    verifyEq(actual.get("type"), expected->type)
    verifyEq(actual.get("subType"), expected->subType)
    verifyEq(actual.get("foo"), null)
    verifyEq(actual.get("foo", "-"), "-")
    verifyErr(UnknownNameErr#) { actual->foo }

    return expected
  }

  private Void verifyCommitsErr(Obj? config, Str msg)
  {
    verifyErrMsg(Err#, msg) { commits(TestObserver(), config) }
  }

  private Subscription commits(TestObserver o, Obj? config)
  {
    rt.obs.get("obsCommits").subscribe(o, Etc.makeDict(config))
  }

//////////////////////////////////////////////////////////////////////////
// Watch
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testWatch()
  {
    a := addRec(["dis":"A", "foo":m])
    b := addRec(["dis":"B", "foo":m])
    c := addRec(["dis":"C", "foo":m, "bar":m])
    d := addRec(["dis":"D", "foo":m, "bar":m])
    e := addRec(["dis":"E", "bar":m])
    f := addRec(["dis":"F", "bar":m])

    x := TestObserver(); xs := rt.obs.get("obsWatches").subscribe(x, Etc.emptyDict)
    y := TestObserver(); ys := rt.obs.get("obsWatches").subscribe(y, Etc.makeDict1("obsFilter", "foo"))
    z := TestObserver(); zs := rt.obs.get("obsWatches").subscribe(z, Etc.makeDict1("obsFilter", "bar"))
    clear := |->| { x.clear; y.clear; z.clear }

    verifyWatch(x, null, null)
    verifyWatch(y, null, null)
    verifyWatch(z, null, null)

    w1 := rt.watch.open("w1")
    w2 := rt.watch.open("w2")

    // b, c, d, e into watch
    w1.addAll([b.id, c.id, d.id, e.id])
    verifyWatch(x, "watch", [b, c, d, e])
    verifyWatch(y, "watch", [b, c, d])
    verifyWatch(z, "watch", [c, d, e])

    // b, c, d, e watch num 2
    clear()
    w2.addAll([b.id, c.id, d.id, e.id])
    verifyWatch(x, null, null)
    verifyWatch(y, null, null)
    verifyWatch(z, null, null)

    // a into watch
    w2.add(a.id)
    verifyWatch(x, "watch", [a])
    verifyWatch(y, "watch", [a])
    verifyWatch(z, null, null)

    // a out of watch
    clear()
    w2.remove(a.id)
    verifyWatch(x, "unwatch", [a])
    verifyWatch(y, "unwatch", [a])
    verifyWatch(z, null, null)

    // close w1 (no changes)
    clear()
    w1.close
    verifyWatch(x, null, null)
    verifyWatch(y, null, null)
    verifyWatch(z, null, null)

    // close w2, b/c/d/e unwatch
    clear()
    w2.close
    verifyWatch(x, "unwatch", [b, c, d, e])
    verifyWatch(y, "unwatch", [b, c, d])
    verifyWatch(z, "unwatch", [c, d, e])
  }

  private Void verifyWatch(TestObserver o, Str? subType, Dict[]? expected)
  {
    rt.sync
    Dict? actual := o.sync
    // echo("\n-- verifyWatch")
    // if (actual != null) { Etc.dictDump(actual); echo(((Dict[])actual->recs).map |r| { r.dis }) }
    if (expected == null)
    {
      verifyNull(actual)
      return
    }

    verifyEq(actual->type, "obsWatches")
    verifyEq(actual->subType, subType)
    verifyDictsEq(actual->recs, expected, false)
  }

//////////////////////////////////////////////////////////////////////////
// CurVals
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testCurVals()
  {
    a1 := addRec(["dis":"A", "foo":m])
    b1 := addRec(["dis":"B", "bar":m])

    x := TestObserver(); xs := rt.obs.get("obsCurVals").subscribe(x, Etc.emptyDict)
    y := TestObserver(); ys := rt.obs.get("obsCurVals").subscribe(y, Etc.makeDict1("obsFilter", "foo"))
    verifyEq(xs.observable.name, "obsCurVals")
    clear := |->| { x.clear; y.clear }

    verifyCurVals(x, a1, null)
    verifyCurVals(y, a1, null)

    // set curVal on foo (both x and y receive)
    a2 := commit(a1, ["curVal":n(123)], Diff.transient)
    verifyCurVals(x, a1, a2)
    verifyCurVals(y, a1, a2)

    // set curStatus on bar (only x receives)
    clear()
    b2 := commit(b1, ["curStatus":"ok"], Diff.transient)
    verifyCurVals(x, b1, b2)
    verifyCurVals(y, b1, null)

    // set non curVal tag on foo (nothing received)
    clear()
    a3 := commit(a2, ["curFoo":"!"], Diff.transient)
    verifyCurVals(x, a2, null)
    verifyCurVals(y, a2, null)

    // set both curVal and curStatus on foo (both x and y receive)
    clear()
    a4 := commit(a3, ["curFoo":"again!", "curVal":n(123), "curStatus":"ok"], Diff.transient)
    verifyCurVals(x, a3, a4)
    verifyCurVals(y, a3, a4)
  }

  private Void verifyCurVals(TestObserver o, Dict oldRec, Dict? newRec)
  {
    rt.sync
    Dict? actual := o.sync
    // echo("\n-- verifyCurVals")
    // if (actual != null) Etc.dictDump(actual)
    if (newRec == null)
    {
      verifyNull(actual)
      return
    }

    verifyEq(actual->type, "obsCurVals")
    verifyEq(actual->subType, "updated")
    verifyRefEq(actual.id, oldRec.id)
    verifyDictEq(actual->oldRec, oldRec)
    verifyDictEq(actual->newRec, newRec)
  }

//////////////////////////////////////////////////////////////////////////
// HisWrites
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testHisWrites()
  {
    tz := TimeZone("New_York")
    a := addRec(["dis":"A", "foo":m, "point":m, "his":m, "kind":"Number", "tz":tz.name])
    b := addRec(["dis":"B", "bar":m, "point":m, "his":m, "kind":"Number", "tz":tz.name])

    x := TestObserver(); xs := rt.obs.get("obsHisWrites").subscribe(x, Etc.emptyDict)
    y := TestObserver(); ys := rt.obs.get("obsHisWrites").subscribe(y, Etc.makeDict1("obsFilter", "foo"))
    verifyEq(xs.observable.name, "obsHisWrites")
    clear := |->| { x.clear; y.clear }

    verifyHisWrites(x, a, -1, null, null)
    verifyHisWrites(y, a, -1, null, null)

    date := Date("2021-08-30")
    ts1 := date.toDateTime(Time("00:01:00"), tz)
    items := [HisItem(ts1, n(1))]
    rt.db.his.write(a.id, items)

    verifyHisWrites(x, a, 1, ts1, ts1)
    verifyHisWrites(y, a, 1, ts1, ts1)

    clear()
    ts2 := date.toDateTime(Time("00:02:00"), tz)
    ts3 := date.toDateTime(Time("00:03:00"), tz)
    items = [HisItem(ts1, n(1)), HisItem(ts2, n(2)), HisItem(ts3, n(3)), HisItem(ts3, n(4))] // dup ts3
    rt.db.his.write(b.id, items)

    verifyHisWrites(x, b, 3, ts1, ts3)
    verifyHisWrites(y, b, -1, null, null)
  }

  private Void verifyHisWrites(TestObserver o, Dict rec, Int count, DateTime? start, DateTime? end)
  {
    rt.sync
    Dict? actual := o.sync
    rec = rt.db.readById(rec.id)
    // echo("\n-- verifyHisWrites")
    // if (actual != null) Etc.dictDump(actual->rec)
    if (start == null)
    {
      verifyNull(actual)
      return
    }

    verifyEq(actual->type, "obsHisWrites")
    verifyRefEq(actual.id, rec.id)
    verifyEq(actual->rec->dis, rec.dis) // no guarantee hisStart, etc synced
    verifyEq(actual->count, n(count))
    verifyEq(actual->span, Span(start, end))
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

