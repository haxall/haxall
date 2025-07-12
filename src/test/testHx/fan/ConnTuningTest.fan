//
// Copyright (c) 2014, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Aug 2014  Brian Frank  Creation
//   25 Jan 2022  Brian Frank  Refactor for Haxall
//

using concurrent
using xeto
using haystack
using folio
using hx
using hxConn


**
** ConnTuningTest
**
class ConnTuningTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Parse
//////////////////////////////////////////////////////////////////////////

  Void testParse()
  {
    r := Etc.makeDict([
        "id": Ref("a", "Test"),
        "pollTime": n(30, "ms"),
        "staleTime": n(1, "hour"),
        "writeMinTime": n(2, "sec"),
        "writeMaxTime": n(3, "sec"),
        "writeOnStart":m,
        "writeOnOpen":m,
        ])

    t := ConnTuning(r)
    verifyEq(t.id, r.id)
    verifyEq(t.dis, "Test")
    verifyEq(t.pollTime, 30ms)
    verifyEq(t.staleTime, 1hr)
    verifyEq(t.writeMinTime, 2sec)
    verifyEq(t.writeOnStart, true)
    verifyEq(t.writeOnOpen, true)
  }

//////////////////////////////////////////////////////////////////////////
// Roster
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testRoster()
  {
    // initial setup
    t1  := addRec(["connTuning":m, "dis":"T-1", "staleTime":n(1, "sec")])
    t2  := addRec(["connTuning":m, "dis":"T-2", "staleTime":n(2, "sec")])
    t3  := addRec(["connTuning":m, "dis":"T-3", "staleTime":n(3, "sec")])
    c   := addRec(["dis":"C", "haystackConn":m])
    pt  := addRec(["dis":"Pt", "point":m, "haystackConnRef":c.id, "kind":"Number"])
    fw  := (ConnFwExt)addLib("conn")
    lib := (ConnExt)addLib("haystack")

    // verify tuning registry in ConnFwExt
    verifyTunings(fw, [t1, t2, t3])
    t4 := addRec(["connTuning":m, "dis":"T-4", "staleTime":n(4, "sec")])
    verifyTunings(fw, [t1, t2, t3, t4])
    t4Old := fw.tunings.get(t4.id)
    t4 = commit(t4, ["dis":"T-4 New", "staleTime":n(44, "sec")])
    verifyTunings(fw, [t1, t2, t3, t4])
    verifySame(fw.tunings.get(t4.id), t4Old)
    t4 = commit(t4, ["connTuning":Remove.val])
    verifyTunings(fw, [t1, t2, t3])

    // verify ConnExt, Conn, ConnPoint tuning....

    // starting off we are using lib defaults
    verifyEq(lib.tuning.id.toStr, "haystack-default")
    verifyEq(lib.tuning.staleTime, 5min)
    verifySame(lib.tuning, lib.conn(c.id).tuning)
    verifySame(lib.tuning, lib.point(pt.id).tuning)

    // add tuning for library
    commit(lib.rec, ["connTuningRef":t1.id])
    rt.sync
    verifyEq(lib.tuning.id, t1.id)
    verifyEq(lib.conn(c.id).tuning.id, t1.id)
    verifyEq(lib.point(pt.id).tuning.id, t1.id)
    verifyEq(lib.tuning.staleTime, 1sec)
    verifySame(lib.tuning, lib.conn(c.id).tuning)
    verifySame(lib.tuning, lib.point(pt.id).tuning)
    verifyTuning(fw, lib, pt, t1, 1sec)

    // add tuning for conn
    commit(c, ["connTuningRef":t2.id])
    sync(c)
    verifyEq(lib.tuning.id, t1.id)
    verifyEq(lib.conn(c.id).tuning.id, t2.id)
    verifyEq(lib.point(pt.id).tuning.id, t2.id)
    verifyNotSame(lib.tuning, lib.conn(c.id).tuning)
    verifySame(lib.conn(c.id).tuning, lib.point(pt.id).tuning)
    verifyTuning(fw, lib, pt, t2, 2sec)

    // add tuning on point
    pt = commit(pt, ["connTuningRef":t3.id])
    sync(c)
    verifyEq(lib.tuning.id, t1.id)
    verifyEq(lib.conn(c.id).tuning.id, t2.id)
    verifyEq(lib.point(pt.id).tuning.id, t3.id)
    verifyNotSame(lib.tuning, lib.conn(c.id).tuning)
    verifyNotSame(lib.conn(c.id).tuning, lib.point(pt.id).tuning)
    verifyTuning(fw, lib, pt, t3, 3sec)

    // restart and verify everything gets wired up correctly
    rt.libsOld.remove("haystack")
    rt.libsOld.remove("conn")
    fw = addLib("conn")
    lib = addLib("haystack", ["connTuningRef":t1.id])
    sync(c)
    verifyEq(lib.tuning.id, t1.id)
    verifyEq(lib.conn(c.id).tuning.id, t2.id)
    verifyEq(lib.point(pt.id).tuning.id, t3.id)
    verifyNotSame(lib.tuning, lib.conn(c.id).tuning)
    verifyNotSame(lib.conn(c.id).tuning, lib.point(pt.id).tuning)
    verifyTuning(fw, lib, pt, t3, 3sec)

    // map pt to tuning which doesn't exist yet
    t5id := genRef("t5")
    pt = commit(pt, ["connTuningRef":t5id])
    sync(c)
    verifyEq(lib.point(pt.id).tuning.id, t5id)
    verifyEq(lib.point(pt.id).tuning.staleTime, 5min)
    verifyDictEq(lib.point(pt.id).tuning.rec, Etc.dict1("id", t5id))

    // now fill in t5
    t5 := addRec(["id":t5id, "dis":"T-5", "connTuning":m, "staleTime":n(123, "sec")])
    sync(c)
    verifyEq(fw.tunings.get(t5id).staleTime, 123sec)
    verifyEq(lib.point(pt.id).tuning.id, t5.id)
    verifyEq(lib.point(pt.id).tuning.staleTime, 123sec)
    verifySame(lib.point(pt.id).tuning.rec, t5)
  }

  Void verifyTunings(ConnFwExt fw, Dict[] expected)
  {
    rt.sync
    actual := fw.tunings.list.dup.sort |a, b| { a.dis <=> b.dis }
    verifyEq(actual.size, expected.size)
    actual.each |a, i|
    {
      e := expected[i]
      verifySame(a.rec, e)
      verifyEq(a.id, e.id)
      verifyEq(a.dis, e.dis)
      verifySame(fw.tunings.get(e.id), a)
    }
  }

  Void verifyTuning(ConnFwExt fw, ConnExt lib, Dict ptRec, Dict tuningRec, Duration staleTime)
  {
    pt := lib.point(ptRec.id)
    t  := fw.tunings.get(tuningRec.id)
    verifySame(pt.tuning, t)
    verifyEq(pt.tuning.staleTime, staleTime)
  }


//////////////////////////////////////////////////////////////////////////
// Times
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testTimes()
  {
    lib := (ConnTestExt)addLib("connTest")
    t := addRec(["connTuning":m, "dis":"T"])
    cr := addRec(["dis":"C1", "connTestConn":m])
    pt := addRec(["dis":"Pt", "point":m, "writable":m, "connTestWrite":"a", "connTestConnRef":cr.id, "connTuningRef":t.id, "kind":"Number", "writeConvert":"*10"])

    rt.sync
    c  := lib.conn(cr.id)

    verifyWriteOnStartAndOnOpen(c)
    verifyWriteMinTime(c, t, pt)
    verifyWriteMaxTime(c, t, pt)
    verifyStaleTime(c, t)
  }

  Void verifyWriteOnStartAndOnOpen(Conn c)
  {
    // create point for y)es, x) no, d)efault
    ty := addRec(["dis":"Y", "connTuning":m, "writeOnStart":m, "writeOnOpen":m])
    tx := addRec(["dis":"Y", "connTuning":m])
    y := addRec(["dis":"Y", "point":m, "writable":m, "connTestWrite":"y", "connTestConnRef":c.id, "connTuningRef":ty.id, "kind":"Number"])
    x := addRec(["dis":"X", "point":m, "writable":m, "connTestWrite":"x", "connTestConnRef":c.id, "connTuningRef":tx.id, "kind":"Number"])
    d := addRec(["dis":"D", "point":m, "writable":m, "connTestWrite":"d", "connTestConnRef":c.id, "kind":"Number"])
    q := addRec(["dis":"Q", "point":m, "writable":m, "connTestWrite":"x", "connTestConnRef":c.id, "kind":"Number"])

    // verify tuning is setup correctly
    sync(c)
    verifyEq(c.point(y.id).tuning.writeOnStart, true)
    verifyEq(c.point(x.id).tuning.writeOnStart, false)
    verifyEq(c.point(d.id).tuning.writeOnStart, false)
    verifyEq(c.point(q.id).tuning.writeOnStart, false)

    // initial state
    verifyEq(rt.isSteadyState, false)
    verifyWrite(y, "unknown", null, 17, null, null)
    verifyWrite(x, "unknown", null, 17, null, null)
    verifyWrite(d, "unknown", null, 17, null, null)
    verifyWrite(q, "unknown", null, 17, null, null)

    // write observations suppressed until steady state
    write(c, y, n(10), 16)
    write(c, x, n(20), 16)
    write(c, d, n(30), 16)
    verifyEq(rt.isSteadyState, false)
    verifyWrite(y, "unknown", n(10), 16, null, null)
    verifyWrite(x, "unknown", n(20), 16, null, null)
    verifyWrite(d, "unknown", n(30), 16, null, null)
    verifyWrite(q, "unknown",  null, 17, null, null)

    // now wait for steady state, then give time for hxPoint
    // msgs to propogate thru to the connector framework
    forceSteadyState
    verifyEq(rt.isSteadyState, true)
    rt.sync
    rt.sync
    c.sync

    // we should have seen the isFirst applied for yes, but not no/default
    verifyWrite(y, "ok",      n(10), 16, n(10), 16)
    verifyWrite(x, "unknown", n(20), 16, null, null)
    verifyWrite(d, "unknown", n(30), 16, null, null)
    verifyWrite(q, "unknown", null, 17, null, null)

    // now after the first one all writes are published
    write(c, y, n(100), 16)
    write(c, x, n(200), 16)
    write(c, d, n(300), 16)
    write(c, q, n(400), 16)
    verifyWrite(y, "ok", n(100), 16, n(100), 16)
    verifyWrite(x, "ok", n(200), 16, n(200), 16)
    verifyWrite(d, "ok", n(300), 16, n(300), 16)
    verifyWrite(q, "ok", n(400), 16, n(400), 16)

    // clear stats
    c.send(HxMsg("clearTests")).get
    verifyWrite(y, "ok", n(100), 16, null, null)
    verifyWrite(x, "ok", n(200), 16, null, null)
    verifyWrite(d, "ok", n(300), 16, null, null)
    verifyEq(numWrites(c), 0)

    // force close and reopen - only yes should has onOpen write
    c.close.get
    c.ping.get
    verifyWrite(y, "ok", n(100), 16, n(100), 16)
    verifyWrite(x, "ok", n(200), 16, null, null)
    verifyWrite(d, "ok", n(300), 16, null, null)
    verifyWriteDebug(y, false, "100 @ 16 [test] onOpen")
    verifyEq(numWrites(c), 1)
  }

  Void verifyWriteMinTime(Conn c, Dict t, Dict pt)
  {
    // initial state (first write short circuited without writeOnStart)
    verifyWrite(pt, "unknown", null, 17, null, null)

    // verify two immediate writes with no min time
    write(c, pt, n(1), 16)
    pt = verifyWrite(pt, "ok", n(1), 16, n(1*10), 16)
    write(c, pt, n(2), 16)
    pt = verifyWrite(pt, "ok", n(2), 16, n(2*10), 16)
    verifyWriteDebug(pt, false, "2 @ 16 [test]")

    // now add a minWriteTime
    verifyEq(c.point(pt.id).tuning.writeMinTime, null)
    t = commit(t, ["writeMinTime":n(100, "ms")])
    sync(c)
    verifyEq(c.point(pt.id).tuning.writeMinTime, 100ms)
    write(c, pt, n(3), 15)
    pt = verifyWrite(pt, "ok", n(3), 15, n(2*10), 16)  // no change
    write(c, pt, n(4), 14)
    pt = verifyWrite(pt, "ok", n(4), 14, n(2*10), 16)  // no change
    wait(80ms)
    pt = verifyWrite(pt, "ok", n(4), 14, n(2*10), 16)  // no change

    // last write wins after minWriteTime expires
    verifyWriteDebug(pt, true, "4 @ 14 [test]")
    wait(80ms)
    forceHouseKeeping(c)
    pt = verifyWrite(pt, "ok", n(4), 14, n(4*10), 14)
    verifyWriteDebug(pt, false, "4 @ 14 [test] minTime")

    // now wait until min write time has passed
    wait(120ms)
    write(c, pt, n(5), 16)
    write(c, pt, null, 15)
    write(c, pt, null, 14)
    pt = verifyWrite(pt, "ok", n(5), 16, n(5*10), 16)  // immediate write

    // another write
    write(c, pt, n(6), 12)
    pt = verifyWrite(pt, "ok", n(6), 12, n(5*10), 16)  // no change
    wait(80ms)
    pt = verifyWrite(pt, "ok", n(6), 12, n(5*10), 16)  // no change

    // last write wins after minWriteTime expires
    verifyWriteDebug(pt, true, "6 @ 12 [test]")
    wait(80ms)
    forceHouseKeeping(c)
    pt = verifyWrite(pt, "ok", n(6), 12, n(6*10), 12)
    verifyWriteDebug(pt, false, "6 @ 12 [test] minTime")

    // cleanup
    write(c, pt, null, 12)
    t = commit(t, ["writeMinTime":Remove.val])
    sync(c)
  }

  Void verifyWriteMaxTime(Conn c, Dict t, Dict pt)
  {
    t = commit(readById(t.id), ["writeMaxTime":n(100, "ms")])

    // first write
    write(c, pt, n(77), 16)
    pt = verifyWrite(pt, "ok", n(77), 16, n(77*10), 16)
    num := numWrites(c)

    // wait and check before/after 100ms
    left := 100ms - (Duration.now - lastWriteTime(pt))
    wait(left - 20ms)
    verifyEq(numWrites(c), num)
    wait(80ms)
    forceHouseKeeping(c)
    verifyEq(numWrites(c), num+1)
    pt = verifyWrite(pt, "ok", n(77), 16, n(77*10), 16)

    // again: wait and check before/after 100ms
    left = 100ms - (Duration.now - lastWriteTime(pt))
    wait(left - 20ms)
    verifyEq(numWrites(c), num+1)
    wait(80ms)
    forceHouseKeeping(c)
    verifyEq(numWrites(c), num+2)
    pt = verifyWrite(pt, "ok", n(77), 16, n(77*10), 16)

    // immediate write
    write(c, pt, n(88), 15)
    pt = verifyWrite(pt, "ok", n(88), 15, n(88*10), 15)
    verifyEq(numWrites(c), num+3)
    verifyWriteDebug(pt, false, "88 @ 15 [test]")

    // wait and check before/after 100ms
    left = 100ms - (Duration.now - lastWriteTime(pt))
    wait(left - 20ms)
    verifyEq(numWrites(c), num+3)
    wait(80ms)
    forceHouseKeeping(c)
    verifyEq(numWrites(c), num+4)
    pt = verifyWrite(pt, "ok", n(88), 15, n(88*10), 15)
    verifyWriteDebug(pt, false, "88 @ 15 [test] maxTime")

    // cleanup
    write(c, pt, null, 12)
    t = commit(t, ["writeMaxTime":Remove.val])
    sync(c)
  }

  Void verifyStaleTime(Conn c, Dict t)
  {
    // setup point with staleTime of 200ms
    t = commit(readById(t.id), ["staleTime":n(100, "ms")])
    pt := addRec(["dis":"Stale", "point":m, "connTestCur":"x", "connTestConnRef":c.id, "testCurVal":n(31), "kind":"Number", "connTuningRef":t.id])
    sync(c)
    verifyEq(c.point(pt.id).tuning.staleTime, 100ms)

    // do read and verify
    c.syncCur([c.point(pt.id)])
    verifyCurVal(pt, n(31), "ok")

    // wait and verify transition to stale
    left := 100ms - (Duration.now - lastCurTime(pt))
    Actor.sleep(left - 20ms)
    forceHouseKeeping(c)
    verifyCurVal(pt, n(31), "ok")
    Actor.sleep(80ms)
    forceHouseKeeping(c)
    verifyCurVal(pt, n(31), "stale")

    // make change
    pt = commit(pt, ["testCurVal":n(1977)], Diff.force)
    forceHouseKeeping(c)
    verifyCurVal(pt, n(31), "stale")
    verify(Duration.now - lastCurTime(pt) > 100ms)

    // put into a watch and verify read
    w := rt.watch.open("verifyStaleTime")
    w.add(pt.id)
    sync(c)
    verifyEq(rt.watch.isWatched(pt.id), true)
    verifyEq(c.point(pt.id).isWatched, true)
    verifyCurVal(pt, n(1977), "ok")
    verify(Duration.now - lastCurTime(pt) < 30ms)

    // wait for while and verify we don't transition to stale while watched
    left = 100ms - (Duration.now - lastCurTime(pt))
    wait(left + 70ms)
    forceHouseKeeping(c)
    verifyCurVal(pt, n(1977), "ok")

    // now unwatch the point
    w.remove(pt.id)
    verifyEq(rt.watch.isWatched(pt.id), false)

    // next house keeping should transition to stale
    wait(60ms)
    forceHouseKeeping(c)
    verifyCurVal(pt, n(1977), "stale")

    // force read of bad status
    pt = commit(pt, ["testCurVal":n(1988), "testCurStatus":"fault"], Diff.force)
    sync(c)
    c.syncCur([c.point(pt.id)])
    verifyCurVal(pt, null, "remoteFault")

    // wait and verify we stay in error state, no transition to stale
    wait(170ms)
    forceHouseKeeping(c)
    verifyCurVal(pt, null, "remoteFault")
  }

  Dict verifyWrite(Dict rec, Str status, Obj? tagVal, Int? tagLevel, Obj? lastVal, Int? lastLevel)
  {
    Conn c := rt.conn.point(rec.id).conn
    rec = readById(rec.id)
    last := c.send(HxMsg("lastWrite", rec.id)).get(1sec)
    // echo("-- $rec.dis " + rec["writeStatus"] + " " + rec["writeVal"] + " @ " + rec["writeLevel"] + " | last=$last | " + rec["writeErr"])
    verifyEq(rec["writeStatus"], status)
    verifyEq(rec["writeVal"],    tagVal)
    verifyEq(rec["writeLevel"], n(tagLevel))
    if (lastVal == null)
      verifyEq(last, null)
    else
      verifyEq(last, "$lastVal @ $lastLevel")
    return rec
  }

  Void verifyWriteDebug(Dict rec, Bool writePending, Str writeLastInfo)
  {
    lines       := rt.conn.point(rec.id).details.splitLines
    linePending := lines.find |x| { x.contains("writePending:") }
    lineLastInfo:= lines.find |x| { x.contains("writeLastInfo:") }
    // echo("-- $rec.dis $linePending | $lineLastInfo")
    verifyEq(linePending.split(':').last, writePending.toStr)
    verifyEq(lineLastInfo.split(':').last, writeLastInfo)
  }

  Dict verifyCurVal(Dict rec, Obj? val, Str status)
  {
    Conn c := rt.conn.point(rec.id).conn
    c.sync

    rec = readById(rec.id)
    // echo("-- $rec.dis " + rec["curVal"] + " @ " + rec["curStatus"])
    verifyEq(rec["curVal"], val)
    verifyEq(rec["curStatus"], status)
    return rec
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Duration lastCurTime(Dict pt)
  {
    Duration.make(rt.conn.point(pt.id)->curState->lastUpdate)
  }

  Duration lastWriteTime(Dict pt)
  {
    Duration.make(rt.conn.point(pt.id)->writeState->lastUpdate)
  }

  Int numWrites(Conn c)
  {
    c.send(HxMsg("numWrites")).get(1sec)
  }

  Void write(Conn c, Dict rec, Obj? val, Int level)
  {
    rt.pointWrite.write(rec, val, level, "test").get
    sync(c)
  }

  Void wait(Duration dur)
  {
    echo("   Waiting $dur.toLocale ...")
    Actor.sleep(dur)
  }

  Void sync(Obj? c)
  {
    rt.sync
    if (c == null) return
    if (c is Conn)
      ((Conn)c).sync
    else
      ((Conn)rt.conn.conn(Etc.toId(c))).sync
  }

  Void forceHouseKeeping(Conn c)
  {
    c.forceHouseKeeping.get(1sec)
    rt.sync
  }
}

