//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using axon
using folio
using hx
using hxConn

**
** ConnTest
**
class ConnTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Model
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testModel()
  {
    addExt("hx.conn")

    h := verifyModel("hx.haystack",  "haystack", "lcwhx", 1sec)
    m := verifyModel("hx.modbus",    "modbus",   "lcw",   null)
    q := verifyModel("hx.mqtt",      "mqtt",     "",      null)
    t := verifyModel("hx.test.conn", "connTest", "lcwh",  33sec)

    verifyEq(t.pollFreqDefault, 33sec)
  }

  ConnModel verifyModel(Str extName, Str prefix, Str flags, Duration? pollFreq)
  {
    ext := (ConnExt)addExt(extName)
    ext.spi.sync

    m := ext.model
    verifyEq(m.name, prefix)
    verifyEq(m.connTag, prefix+"Conn")
    verifyEq(m.connRefTag, prefix+"ConnRef")

    verifyEq(m.hasLearn,    flags.contains("l"), "$prefix learn")
    verifyEq(m.hasCur,      flags.contains("c"), "$prefix cur")
    verifyEq(m.hasWrite,    flags.contains("w"), "$prefix write")
    verifyEq(m.hasHis,      flags.contains("h"), "$prefix his")
    verifyEq(m.pollFreqDefault, pollFreq)

    if (m.hasCur)
    {
      verifyEq(m.curTag, "${prefix}Cur")
      verifyEq(m.curTagType, Str#)
    }

    verifyEq(m.writeLevelTag !== null, flags.contains("x"), "$prefix writeLevel")

    return m
  }

//////////////////////////////////////////////////////////////////////////
// Service
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testService()
  {
    // empty
    verifyEq(proj.exts.conn(false), null)
    verifyErr(UnknownExtErr#) { proj.exts.conn }
    verifyErr(UnknownExtErr#) { proj.exts.conn(true) }

    // add haystack lib
    addExt("hx.haystack")
    verifyService(
      ["hx.haystack"],
      [,],
      [,])

    // add conns
    c1 := addRec(["dis":"C1", "haystackConn":m])
    c2 := addRec(["dis":"C2", "haystackConn":m])
    c3 := addRec(["dis":"C3", "haystackConn":m])
    c4 := addRec(["dis":"C3", "sqlConn":m])
    verifyService(
      ["hx.haystack"],
      [c1, c2, c3],
      [,])

    // add points
    p1 := addRec(["dis":"P1", "haystackConnRef":c1.id, "point":m])
    p2 := addRec(["dis":"P2", "haystackConnRef":c2.id, "point":m])
    p3 := addRec(["dis":"P3", "haystackConnRef":c3.id, "point":m])
    p4 := addRec(["dis":"P4", "sqlConnRef":c4.id, "point":m])
    verifyService(
      ["hx.haystack"],
      [c1, c2, c3],
      [p1, p2, p3])

    // remove points
    p2 = commit(p2, ["point":None.val])
    commit(p3, null, Diff.remove)
    verifyService(
      ["hx.haystack"],
      [c1, c2, c3],
      [p1])

    // add them back
    p2 = commit(p2, ["point":m])
    p3 = addRec(["dis":"P3", "haystackConnRef":c3.id, "point":m])

    // add sql lib
    addExt("hx.sql")
    verifyService(
      ["hx.haystack", "hx.sql"],
      [c1, c2, c3, c4],
      [p1, p2, p3, p4])

    // remove connector
    c3 = commit(c3, ["trash":m])
    verifyService(
      ["hx.haystack", "hx.sql"],
      [c1, c2, c4],
      [p1, p2, p4])

    // remove sql lib
    proj.libs.remove("hx.sql")
    verifyService(
      ["hx.haystack"],
      [c1, c2],
      [p1, p2])

    // remove haystack lib
    proj.libs.remove("hx.haystack")
    verifyService(
      Str[,],
      [,],
      [,])

    // verify bad
    c := proj.exts.conn
    verifyEq(c.ext("bad", false), null)
    verifyErr(UnknownConnExtErr#) { c.ext("bad") }
    verifyErr(UnknownConnExtErr#) { c.ext("bad", true) }
    verifyEq(c.conn(Ref.gen, false), null)
    verifyErr(UnknownConnErr#) { c.conn(Ref.gen) }
    verifyErr(UnknownConnErr#) { c.conn(Ref.gen, true) }
    verifyEq(c.point(Ref.gen, false), null)
    verifyErr(UnknownConnPointErr#) { c.point(Ref.gen) }
    verifyErr(UnknownConnPointErr#) { c.point(Ref.gen, true) }
  }

  private Void verifyService(Str[] libs, Dict[] conns, Dict[] points)
  {
    c := proj.sync.exts.conn

    /*
    echo("--- Service ---")
    echo("  exts:   " + c.exts.join(","))
    echo("  conns:  " + c.conns.join(",") { it.rec.dis })
    echo("  points: " + c.points.join(",") { it.rec.dis })
    */

    verifyEq(c.exts.map |x->Str| { x.name }, libs)
    verifyEq(c.conns.map {it.rec.dis} .sort, conns.map {it.dis})
    verifyEq(c.points.map {it.rec.dis} .sort, points.map {it.dis})
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testUtil()
  {
    lib := (ConnExt)addExt("hx.haystack")
    c1 := addRec(["dis":"C1", "haystackConn":m])
    c2 := addRec(["dis":"C2", "haystackConn":m])
    c3 := addRec(["dis":"C3", "haystackConn":m])
    p1 := addRec(["dis":"P1", "haystackConnRef":c1.id, "point":m])
    p2 := addRec(["dis":"P2", "haystackConnRef":c1.id, "point":m])
    p3 := addRec(["dis":"P3", "haystackConnRef":c2.id, "point":m])
    p4 := addRec(["dis":"P4", "haystackConnRef":c2.id, "point":m])
    p5 := addRec(["dis":"P5", "haystackConnRef":c3.id, "point":m])
    p6 := addRec(["dis":"P6", "haystackConnRef":c3.id, "point":m])
    proj.sync

    verifyPointsToConn([,], Str[,])
    verifyPointsToConn([p2], ["C1: P2"])
    verifyPointsToConn([p1, p2], ["C1: P1,P2"])
    verifyPointsToConn([p3, p4], ["C2: P3,P4"])
    verifyPointsToConn([p1, p2, p3, p4], ["C1: P1,P2", "C2: P3,P4"])
    verifyPointsToConn([p1, p5, p3, p2, p6, p4], ["C1: P1,P2", "C2: P3,P4", "C3: P5,P6"])
  }

  Void verifyPointsToConn(Dict[] pointRecs, Str[] expected)
  {
    actual := Str[,]
    points := pointRecs.map |rec->ConnPoint| { proj.exts.conn.point(rec.id) }
    ConnUtil.eachConnInPointIds(proj, points) |c, pts|
    {
      actual.add("$c.dis: " + pts.join(",") { it.dis })
    }
    actual.sort
    verifyEq(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// Trace
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testTrace()
  {
    // empty roster
    lib := (ConnExt)addExt("hx.haystack")
    rec := addRec(["dis":"Test Conn", "haystackConn":m])
    proj.sync
    c := lib.conn(rec.id)

    // start off empty
    verifyEq(c.trace.isEnabled, false)
    verifyEq(c.trace.asLog.level, LogLevel.silent)
    verifyTrace(c, [,])

    // write a trace while disalbed
    c.trace.write("foo", "msg", null)
    verifyTrace(c, [,])

    // now enable it
    c.trace.enable
    verifyEq(c.trace.isEnabled, true)
    verifyEq(c.trace.asLog.level, LogLevel.debug)
    c.trace.write("foo", "msg", null)
    verifyTrace(c, [
      ["foo", "msg", null],
      ])

    // write some other traces
    c.trace.dispatch(HxMsg("x"))
    c.trace.req("req test", "req body")
    Actor.sleep(10ms)
    c.trace.res("res test", "res body")
    c.trace.event("event test", "event body")
    verifyTrace(c, [
      ["foo",      "msg",        null],
      ["dispatch", "x",          HxMsg("x")],
      ["req",      "req test",   "req body"],
      ["res",      "res test",   "res body"],
      ["event",    "event test", "event body"],
      ])

    // verify re-enable doesn't change anything
    c.trace.enable
    verifyEq(c.trace.isEnabled, true)
    verifyEq(c.trace.asLog.level, LogLevel.debug)
    verifyTrace(c, [
      ["foo",      "msg",        null],
      ["dispatch", "x",          HxMsg("x")],
      ["req",      "req test",   "req body"],
      ["res",      "res test",   "res body"],
      ["event",    "event test", "event body"],
      ])

    // readSince
    verifyTrace(c, [
      ["res",      "res test",   "res body"],
      ["event",    "event test", "event body"],
      ], c.trace.read[2].ts)

    // disable
    c.trace.disable
    verifyEq(c.trace.isEnabled, false)
    verifyEq(c.trace.asLog.level, LogLevel.silent)
    verifyTrace(c, [,])
    c.trace.write("ignore", "ignore")
    verifyTrace(c, [,])

    // buf test
    c.trace.enable
    buf := "buf test".toBuf
    verifyErr(NotImmutableErr#) { c.trace.req("bad", buf) }
    buf = buf.toImmutable
    c.trace.req("req test", buf)
    verify(buf.bytesEqual("buf test".toBuf))
  }

  Void verifyTrace(Conn c, Obj[] expected, DateTime? since := null)
  {
    c.sync
    actual := c.trace.readSince(since)
    actual = actual.findAll |a| { a.msg != "sync" && a.msg != "init" && a.msg != "poll" }
    if (actual.size != expected.size)
    {
      echo("\n --- trace $since ---"); echo(actual.join("\n"))
    }
    verifyEq(actual.size, expected.size)
    actual.each |a, i|
    {
      e := (Obj?[]) expected[i]
      verifyEq(a.ts.date, Date.today)
      verifyEq(a.type, e[0])
      verifyEq(a.msg,  e[1])
      if (e[2] is Func)
        ((Func)e[2])(a.arg)
      else
        verifyEq(a.arg,  e[2])
    }
  }

//////////////////////////////////////////////////////////////////////////
// Roster
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testRoster()
  {
    // empty roster
    lib := (ConnExt)addExt("hx.haystack")
    verifyRoster(lib, [,])

    // add connector
    c1 := addRec(["dis":"C1", "haystackConn":m])
    proj.sync
    verifyRoster(lib,
      [
       [c1],
      ])

    // add two more
    c2 := addRec(["dis":"C2", "haystackConn":m])
    c3 := addRec(["dis":"C3", "haystackConn":m])
    proj.sync
    verifyRoster(lib,
      [
       [c1],
       [c2],
       [c3],
      ])

    // lookup conns and turn turn on tracing
    conn1 := lib.conn(c1.id)
    conn2 := lib.conn(c2.id)
    conn3 := lib.conn(c3.id)
    lib.conns.each |c| { c.trace.enable }

    // modify c2
    c2 = commit(c2, ["change":m, "dis":"C2x"])
    proj.sync
    verifyRoster(lib,
      [
       [c1],
       [c2],
       [c3],
      ])
    verifyTrace(conn2, [
      ["dispatch", "connUpdated", HxMsg("connUpdated", c2)],
      ])

    // add some points
    p1a := addRec(["dis":"1A", "point":m, "haystackConnRef":c1.id, "haystackCur":"1", "kind":"Number"])
    p1b := addRec(["dis":"1B", "point":m, "haystackConnRef":c1.id, "haystackCur":"2", "kind":"Number"])
    p1c := addRec(["dis":"1C", "point":m, "haystackConnRef":c1.id, "haystackCur":"3", "kind":"Number"])
    p2a := addRec(["dis":"2A", "point":m, "haystackConnRef":c2.id, "haystackCur":"4", "kind":"Number"])
    proj.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1b, p1c],
       [c2, p2a],
       [c3],
      ])
    verifyTrace(conn1, [
      ["dispatch", "pointAdded", HxMsg("pointAdded", conn1.point(p1a.id))],
      ["dispatch", "pointAdded", HxMsg("pointAdded", conn1.point(p1b.id))],
      ["dispatch", "pointAdded", HxMsg("pointAdded", conn1.point(p1c.id))],
      ])

    // update pt
    conn1.trace.clear
    p1b = commit(p1b, ["dis":"1Bx", "change":"it"])
    proj.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1b, p1c],
       [c2, p2a],
       [c3],
      ])
    verifyTrace(conn1, [
      ["dispatch", "pointUpdated", HxMsg("pointUpdated", conn1.point(p1b.id), p1b)],
      ])

    // setup points in watch
    watch := proj.watch.open("test")
    watch.addAll([p1a.id, p1b.id, p1c.id])
    verifyWatched(conn1, [p1a, p1b, p1c])
    watch.remove(p1c.id)
    verifyWatched(conn1, [p1a, p1b])

    // move pt to new connector
    conn1.trace.clear
    conn3.trace.clear
    p1bOld := conn1.point(p1b.id)
    p1b = commit(p1b, ["dis":"3A", "haystackConnRef":c3.id])
    proj.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
      ])
    verifyTrace(conn1, [
      ["dispatch", "pointRemoved", HxMsg("pointRemoved", p1bOld)],
      ])
    verifyTrace(conn3, [
      ["dispatch", "pointAdded", HxMsg("pointAdded", conn3.point(p1b.id))],
      ])
    verifyWatched(conn1, [p1a])
    verifyWatched(conn3, [p1b])

    // create some points which don't map to connectors yet
    c4id := genRef("c4")
    p4a := addRec(["dis":"4A", "point":m, "haystackConnRef":c4id, "haystackCur":"4a", "kind":"Number"])
    p4b := addRec(["dis":"4B", "point":m, "haystackConnRef":"bad ref", "haystackCur":"4b", "kind":"Number"])
    watch.addAll([p4a.id, p4b.id])
    proj.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
      ])

    // now add c4
    c4 := addRec(["id":c4id, "dis":"C4", "haystackConn":m])
    verifyEq(c4.id, c4id)
    proj.sync
    conn4 := lib.conn(c4.id)
    conn4.trace.enable
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
       [c4, p4a],
      ])
    verifyWatched(conn1, [p1a])
    verifyWatched(conn3, [p1b])
    verifyWatched(conn4, [p4a])

    // fix p4b which had bad ref
    p4b = commit(p4b, ["haystackConnRef":c4.id])
    proj.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
       [c4, p4a, p4b],
      ])
    verifyTrace(conn4, [
      ["dispatch", "pointAdded", HxMsg("pointAdded", conn4.point(p4b.id))],
      ])
    verifyWatched(conn4, [p4a, p4b])

    // remove points
    p4aOld := conn4.point(p4a.id)
    p4bOld := conn4.point(p4b.id)
    conn4.trace.clear
    p4a = commit(p4a, ["point":None.val])
    p4b = commit(p4b, ["trash":m])
    proj.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
       [c4],
      ])
    verifyTrace(conn4, [
      ["dispatch", "pointRemoved", HxMsg("pointRemoved", p4aOld)],
      ["dispatch", "pointRemoved", HxMsg("pointRemoved", p4bOld)],
      ])
    verifyWatched(conn4, [,])

    // add them back
    conn4.trace.clear
    p4a = commit(p4a, ["point":m])
    p4b = commit(p4b, ["trash":None.val])
    proj.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
       [c4, p4a, p4b],
      ])
    verifyTrace(conn4, [
      ["dispatch", "pointAdded", HxMsg("pointAdded", conn4.point(p4a.id))],
      ["dispatch", "pointAdded", HxMsg("pointAdded", conn4.point(p4b.id))],
      ])
    verifyWatched(conn4, [p4a, p4b])

    // remove c2 and c3
    c2Old := lib.conn(c2.id)
    c3Old := lib.conn(c2.id)
    verifyEq(c2Old.isAlive, true)
    verifyEq(c3Old.isAlive, true)
    c2 = commit(c2, ["haystackConn":None.val])
    c3 = commit(c3, ["trash":m])
    proj.sync
    verifyErr(UnknownConnErr#) { lib.conn(c2.id) }
    verifyErr(UnknownConnErr#) { lib.conn(c3.id, true) }
    verifyEq(c2Old.isAlive, false)
    verifyEq(c3Old.isAlive, false)
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c4, p4a, p4b],
      ])

    // add back c2 and c3
    c2 = commit(c2, ["haystackConn":m])
    c3 = commit(c3, ["trash":None.val])
    proj.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
       [c4, p4a, p4b],
      ])
    verifyWatched(conn1, [p1a])
    verifyWatched(conn3, [p1b])
    verifyWatched(conn4, [p4a, p4b])

    // now restart lib
    proj.libs.remove(lib.name)
    lib = addExt("hx.haystack")
    proj.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
       [c4, p4a, p4b],
      ])
    verifyWatched(conn1, [p1a])
    verifyWatched(conn3, [p1b])
    verifyWatched(conn4, [p4a, p4b])

    // now change isCurEnabled and check watch updates
    p4b = commit(p4b, ["haystackCur":None.val])
    verifyWatched(conn4, [p4a, p4b], [p4a])
    p4a = commit(p4a, ["haystackCur":n(123)])
    p4b = commit(p4b, ["haystackCur":"back"])
    verifyWatched(conn4, [p4a, p4b], [p4b])
  }

  Void verifyRoster(ConnExt lib, Dict[][] expected)
  {
    // echo; lib->roster->dump
    conns := lib.conns
    verifySame(lib.conns, conns)
    verifyEq(lib.conns, conns.dup.sort |a, b| { a.dis <=> b.dis })
    verifyEq(conns.size, expected.size)
    exAllPoints := Dict[,]

    // each connector
    conns.each |c, i|
    {
      c.sync
      // expected rows are a list where first item is connector rec
      // and rest of list is the expected points under that connector
      ex    := expected[i]
      exRec := ex[0]
      exPts := ex[1..-1]
      exAllPoints.addAll(exPts)

      // connector
      verifySame(c.ext, lib)
      verifyRecEq(c.rec, exRec)
      verifyEq(c.id, exRec.id)
      verifyEq(c.dis, exRec.dis)
      verifySame(lib.conn(exRec.id), c)
      verifySame(proj.exts.conn.conn(c.id), c)

      // points
      verifyPoints(lib, c.points, exPts, false)
      c.points.each |pt|
      {
        verifySame(pt.conn, c)
        verifySame(proj.exts.conn.point(pt.id), pt)
      }

      // connPoints axon func
      Dict[] ptRecs := eval("connPoints($c.id.toCode)")
      verifyEq(ptRecs.size, c.points.size)
      verifyDictsEq(ptRecs, proj.db.readByIdsList(c.pointIds))

      // bad points
      verifyEq(c.point(Ref.gen, false), null)
      verifyErr(UnknownConnPointErr#) { c.point(Ref.gen) }
      verifyErr(UnknownConnPointErr#) { c.point(Ref.gen, true) }
    }

    // all points
    verifyPoints(lib, lib.points, exAllPoints, true)

    // bad conn ids
    verifyEq(lib.conn(Ref.gen, false), null)
    verifyErr(UnknownConnErr#) { lib.conn(Ref.gen) }
    verifyErr(UnknownConnErr#) { lib.conn(Ref.gen, true) }
  }

  Void verifyPoints(ConnExt lib, ConnPoint[] actual, Dict[] expected, Bool sort)
  {
    if (sort) actual = actual.dup.sort |a, b| { a.dis <=> b.dis }
    verifyEq(actual.size, expected.size)
    actual.each |a, i|
    {
      e := expected[i]
      id := e.id
      connRef := (Ref)e["haystackConnRef"]
      verifyEq(a.conn.id, connRef)
      verifySame(a.conn, lib.conn(connRef))
      verifyRecEq(a.rec, e)
      verifyEq(a.id, id)
      verifyEq(a.dis, e.dis)
      verifySame(lib.point(id), a)
      verifySame(a.conn.point(id), a)
      verifySame(proj.exts.conn.point(id), a)

      // verify Conn.point wrong connector
      lib.conns.each |c|
      {
        if (a.conn === c) return
        verifyEq(c.point(id, false), null)
        verifyErr(UnknownConnPointErr#) { c.point(id) }
        verifyErr(UnknownConnPointErr#) { c.point(id, true) }
      }
    }
  }

  Void verifyRecEq(Dict a, Dict b)
  {
    // we don't expect transient tags to be same
    verifySame(a.id, b.id)
    verifySame(a.dis, b.dis)
    verifySame(a->mod, b->mod)
  }

  Void verifyWatched(Conn c, Dict[] points, Dict[]? expectedInWatch := points)
  {
    proj.sync
    c.sync
    //echo("-- verifyWatched $c.dis " + points.join(",") { it.dis })

    // walk thru points and check isWatched flag
    c.points.each |pt|
    {
      isWatched := points.any { it.id == pt.id }
      verifyEq(pt.isWatched, isWatched, pt.dis)
    }

    // also verify the pointsInWatch list
    actualInWatch := (Dict[])eval("connPointsInWatch($c.id.toCode)")
    actualInWatch = actualInWatch.dup.sort |a, b| { a.dis <=> b.dis }
    //echo("   inWatch = '" + actualInWatch.join(",") { it.dis } + "'")
    verifyEq(expectedInWatch.join(",") { it.dis }, actualInWatch.join(",") { it.dis })

    c.trace.clear
  }

//////////////////////////////////////////////////////////////////////////
// Config
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testConfig()
  {
    lib := (ConnExt)addExt("hx.haystack")

    // conn with defaults
    cr := addRec(["dis":"TestConn", "haystackConn":m])
    proj.sync
    c := lib.conn(cr.id)
    verifyEq(c.id, cr.id)
    verifyEq(c.dis, "TestConn")
    verifySame(c.rec, cr)
    verifyEq(c.timeout, 1min)
    verifyEq(c.linger, 30sec)
    verifyEq(c.pingFreq, null)
    verifyEq(c.pollFreq, 1sec)
    verifyEq(c.openRetryFreq, 10sec)

    // update config
    cr = commit(cr, ["actorTimeout":n(27, "sec"), "connLinger":n(5, "sec"), "connPingFreq":n(1, "min"), "haystackPollFreq":n(5, "sec"), "connOpenRetryFreq":n(7, "sec")])
    sync(c)
    verifySame(lib.conn(cr.id), c)
    verifyEq(c.id, cr.id)
    verifyEq(c.dis, "TestConn")
    verifySame(c.rec, cr)
    verifyEq(c.timeout, 27sec)
    verifyEq(c.linger, 5sec)
    verifyEq(c.pingFreq, 1min)
    verifyEq(c.pollFreq, 5sec)
    verifyEq(c.openRetryFreq, 7sec)

    // update config with invalid values
    cr = commit(cr, ["actorTimeout":"bad", "connLinger":"bad", "connPingFreq":"bad", "haystackPollFreq":"bad"])
    sync(c)
    verifySame(lib.conn(cr.id), c)
    verifyEq(c.id, cr.id)
    verifyEq(c.dis, "TestConn")
    verifySame(c.rec, cr)
    verifyEq(c.timeout, 1min)
    verifyEq(c.linger, 30sec)
    verifyEq(c.pingFreq, null)
    verifyEq(c.pollFreq, 1sec)

    // point with all tags
    pr := addRec(["dis":"Pt", "haystackConnRef":c.id, "point":m,
       "tz":"Chicago", "kind":"Number", "unit":"kW",
       "haystackCur":"c", "haystackHis":"h", "haystackWrite":"w",
       "curConvert":"*7", "writeConvert":"*8", "hisConvert":"*9"])
    sync(c)
    p := c.point(pr.id)
    verifyEq(p.id, pr.id)
    verifyEq(p.dis, "Pt")
    verifySame(p.rec, pr)
    verifyEq(p.tz, TimeZone("Chicago"))
    verifyEq(p.unit, Unit("kW"))
    verifyEq(p.kind, Kind.number)
    verifyEq(p.isCurEnabled, true);   verifyEq(p.curAddr,   "c")
    verifyEq(p.isWriteEnabled, true); verifyEq(p.writeAddr, "w")
    verifyEq(p.isHisEnabled, true);   verifyEq(p.hisAddr,   "h")
    verifyEq(p.curConvert.toStr,   "* 7.0")
    verifyEq(p.writeConvert.toStr, "* 8.0")
    verifyEq(p.hisConvert.toStr,   "* 9.0")

    // start from bottom up and check faults
    verifyPtFault(p, "hisConvert", n(3),   "Point convert not string: 'hisConvert'")
    verifyPtFault(p, "writeConvert", "%^", "Point convert invalid: 'writeConvert'")
    verifyPtFault(p, "curConvert", "kW=>", "Point convert invalid: 'curConvert'")
    verifyPtFault(p, "kind", "Bad", "Invalid 'kind' tag: Bad [$p.id.toZinc]")
    verifyPtFault(p, "kind", n(3), "Invalid type for 'kind' tag: haystack::Number [$p.id.toZinc]")
    verifyPtFault(p, "kind", null, "Missing 'kind' tag [$p.id.toZinc]")
    verifyPtFault(p, "unit", "blah", "Invalid 'unit' tag: blah [$p.id.toZinc]")
    verifyPtFault(p, "unit", n(2), "Invalid type for 'unit' tag: haystack::Number [$p.id.toZinc]")
    verifyPtFault(p, "tz", "Wrong", "Invalid 'tz' tag: Wrong [$p.id.toZinc]")
    verifyPtFault(p, "tz", n(1), "Invalid type for 'tz' tag: haystack::Number [$p.id.toZinc]")
    verifyPtFault(p, "haystackCur", n(2), "Invalid type for 'haystackCur' [Number != Str]")
    verifyPtFault(p, "haystackHis", Ref("foo"), "Invalid type for 'haystackHis' [Ref != Str]")
    verifyPtFault(p, "haystackWrite", `foo`, "Invalid type for 'haystackWrite' [Uri != Str]")
  }

  Void verifyPtFault(ConnPoint p, Str tag, Obj? val, Str msg)
  {
    rec := commit(readById(p.id), [tag: val ?: None.val])
    proj.sync
    p.conn.sync
    //echo("-- $tag = $val $p.fault")
    verifyEq(p.id, rec.id)
    verifyEq(p.dis, rec.dis)
    verifySame(p.rec, rec)
    switch (tag)
    {
      case "haystackWrite": verifyEq(p->config->writeFault, msg)
      case "haystackHis":   verifyEq(p->config->hisFault, msg)
      default:              verifyEq(p->config->curFault, msg)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Test Poll Buckets
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testBuckets()
  {
    name := "modbus"
    connTag := name + "Conn"
    connTagRef := name + "ConnRef"
    extName := "hx." + name
    lib := (ConnExt)addExt(extName)

    // setup connectors
    c1rec := addRec(["dis":"C1", connTag:m])
    c2rec := addRec(["dis":"C2", connTag:m])
    proj.sync
    c1 := lib.conn(c1rec.id)
    c2 := lib.conn(c2rec.id)
    c1b := verifyBuckets(c1, null, [,])
    c2b := verifyBuckets(c2, null, [,])

    // add some points with no tuning recs
    p1 := addRec(["dis":"P1", "point":m, connTagRef:c1.id, "kind":"Number"])
    p2 := addRec(["dis":"P2", "point":m, connTagRef:c1.id, "kind":"Number"])
    p3 := addRec(["dis":"P3", "point":m, connTagRef:c2.id, "kind":"Number"])
    c1b = verifyBuckets(c1, c1b, [
      ["$name-default", 10sec, p1, p2],
      ])
    c2b = verifyBuckets(c2, c2b, [
      ["$name-default", 10sec, p3],
      ])

    // add tuning rec
    tx := addRec(["dis":"TX", "connTuning":m, "pollTime":n(30, "sec")])
    p4 := addRec(["dis":"P4", "point":m, connTagRef:c1.id, "connTuningRef":tx.id, "kind":"Number"])
    proj.sync
    lib.fw.spi.sync
    verifyEq(lib.fw.tunings.get(tx.id).dis, "TX")
    verifyEq(lib.fw.tunings.get(tx.id).pollTime, 30sec)
    verifySame(lib.fw.tunings.get(tx.id), lib.point(p4.id).tuning) // verify ConnPoint hasn't failed before tuning lookup
    c1b = verifyBuckets(c1, c1b, [
      ["$name-default", 10sec, p1, p2],
      ["TX",            30sec, p4],
      ])
    c2b = verifyBuckets(c2, c2b, [
      ["$name-default", 10sec, p3],
      ])

    // assign tuning record to connector
    ty := addRec(["dis":"TY", "connTuning":m, "pollTime":n(7, "sec")])
    c1rec = commit(c1rec, ["connTuningRef":ty.id])
    c1b = verifyBuckets(c1, c1b, [
      ["TY",  7sec, p1, p2],
      ["TX", 30sec, p4],
      ])
    c2b = verifyBuckets(c2, c2b, [
      ["$name-default", 10sec, p3],
      ])

    // move point
    p2 = commit(p2, [connTagRef:c2.id])
    c1b = verifyBuckets(c1, c1b, [
      ["TY",  7sec, p1],
      ["TX", 30sec, p4],
      ])
    c2b = verifyBuckets(c2, c2b, [
      ["$name-default", 10sec, p2, p3],
      ])

    // update connTuningRef on a point
    p1 = commit(p1, ["connTuningRef":tx.id])
    c1b = verifyBuckets(c1, c1b, [
      ["TX", 30sec, p1, p4],
      ])
    c2b = verifyBuckets(c2, c2b, [
      ["$name-default", 10sec, p2, p3],
      ])

    // remove connTuningRef on point
    p1 = commit(p1, ["connTuningRef":None.val])
    c1b = verifyBuckets(c1, c1b, [
      ["TY",  7sec, p1],
      ["TX", 30sec, p4],
      ])
    c2b = verifyBuckets(c2, c2b, [
      ["$name-default", 10sec, p2, p3],
      ])

    // add point
    p5 := addRec(["dis":"P5", "point":m, connTagRef:c1.id, "kind":"Number"])
    c1b = verifyBuckets(c1, c1b, [
      ["TY",  7sec, p1, p5],
      ["TX", 30sec, p4],
      ])
    c2b = verifyBuckets(c2, c2b, [
      ["$name-default", 10sec, p2, p3],
      ])

    // change connTuningRef on conn
    c1rec = commit(c1rec, ["connTuningRef":tx.id])
    c1b = verifyBuckets(c1, c1b, [
      ["TX", 30sec, p1, p4, p5],
      ])
    c2b = verifyBuckets(c2, c2b, [
      ["$name-default", 10sec, p2, p3],
      ])

    // remove connTuningRef on conn
    c1rec = commit(c1rec, ["connTuningRef":None.val])
    c1b = verifyBuckets(c1, c1b, [
      ["$name-default", 10sec, p1, p5],
      ["TX",            30sec, p4],
      ])
    c2b = verifyBuckets(c2, c2b, [
      ["$name-default", 10sec, p2, p3],
      ])

    // restart
    proj.libs.remove(extName)
    lib = addExt(extName)
    proj.sync
    c1 = lib.conn(c1rec.id)
    c2 = lib.conn(c2rec.id)
    c1b = verifyBuckets(c1, null, [
      ["$name-default", 10sec, p1, p5],
      ["TX",            30sec, p4],
      ])
    c2b = verifyBuckets(c2, null, [
      ["$name-default", 10sec, p2, p3],
      ])
  }

  ConnPollBucket[] verifyBuckets(Conn c, ConnPollBucket[]? old, Obj[][] expected)
  {
    proj.sync
    c.ext.spi.sync
    c.sync

    if (false)
    {
      echo
      echo("-- verifyBuckets $c [$c.pollBuckets.size]")
      c.pollBuckets.each |b| { echo("  $b.tuning.dis $b.pollTime => " + b.points.join(", ") { it.dis }) }
    }

    verifyEq(c.pollBuckets.size, expected.size)
    c.pollBuckets.each |b, i|
    {
      e := expected[i]
      ptsStr := b.points.join(", ") { it.dis }
      verifyEq(b.tuning.dis, e[0])
      verifyEq(b.pollTime,   e[1])
      verifyEq(ptsStr,       e[2..-1].join(", ") { it->dis })
    }

    if (old != null)
    {
      c.pollBuckets.each |b|
      {
        oldMatch := old.find { it.tuning.id == b.tuning.id }
        if (oldMatch != null)
          verifySame(oldMatch.state, b.state)
      }
    }

    return c.pollBuckets
  }

//////////////////////////////////////////////////////////////////////////
// Test Status
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testStatus()
  {
    lib := (ConnTestExt)addExt("hx.test.conn")
    c1rec := addRec(["dis":"C1", "connTestConn":m])
    c2rec := addRec(["dis":"C2", "connTestConn":m, "disabled":m])
    forceSteadyState
    proj.sync
    c1 := lib.conn(c1rec.id)
    c2 := lib.conn(c2rec.id)

    // initial state
    verifyConnStatus(c1, "unknown", "closed")
    verifyConnStatus(c2, "disabled", "closed")

    // disabled/enable transitions
    c1rec = commit(c1rec, ["disabled":m])
    c2rec = commit(c2rec, ["disabled":None.val])
    verifyConnStatus(c1, "disabled", "closed")
    verifyConnStatus(c2, "unknown", "closed")

    // add some points
    tz  := "New_York"
    p1  := addRec(["dis":"P1",  "point":m, "kind":"Number", "tz":tz, "connTestConnRef":c1.id, "connTestCur":"x", "connTestWrite":"x", "connTestHis":"x", "writable":m])
    p2  := addRec(["dis":"P2",  "point":m, "kind":"Number", "tz":tz, "connTestConnRef":c1.id, "connTestCur":"x", "connTestWrite":"x", "connTestHis":"x", "writable":m, "disabled":m])
    p3  := addRec(["dis":"P3",  "point":m, "kind":"Number", "tz":tz, "connTestConnRef":c1.id, "connTestCur":"down", "connTestWrite":"x", "writable":m])
    p4  := addRec(["dis":"P4",  "point":m, "kind":"Number", "tz":tz, "connTestConnRef":c1.id, "connTestCur":"x"])
    p5  := addRec(["dis":"P5",  "point":m, "connTestConnRef":c1.id, "haystackCur":"x"])
    p6  := addRec(["dis":"P6",  "point":m, "kind":"Number", "tz":tz, "connTestConnRef":c2.id, "connTestCur":"x", "connTestWrite":"x", "connTestHis":"x"])
    p7  := addRec(["dis":"P7",  "point":m, "kind":"Number", "tz":tz, "connTestConnRef":c2.id, "connTestCur":"x", "connTestWrite":"x", "connTestHis":"x", "disabled":m])
    p8  := addRec(["dis":"P8",  "point":m, "kind":"Number", "tz":tz, "connTestConnRef":c2.id, "connTestCur":"x", "connTestWrite":"x"])
    p9  := addRec(["dis":"P9",  "point":m, "kind":"Number", "tz":tz, "connTestConnRef":c2.id, "connTestCur":"x"])
    p10 := addRec(["dis":"P10", "point":m, "connTestConnRef":c2.id, "connTestCur":"x"])

    verifyPointStatus(p1,  "disabled")
    verifyPointStatus(p2,  "disabled")
    verifyPointStatus(p3,  "disabled")
    verifyPointStatus(p4,  "disabled")
    verifyPointStatus(p5,  "fault")
    verifyPointStatus(p6,  "unknown")
    verifyPointStatus(p7,  "disabled")
    verifyPointStatus(p8,  "unknown")
    verifyPointStatus(p9,  "unknown")
    verifyPointStatus(p10, "fault")

    // disable/enable conn transition again with points
    c1rec = commit(c1rec, ["disabled":None.val])
    c2rec = commit(c2rec, ["disabled":m])
    verifyConnStatus(c1, "unknown", "closed")
    verifyConnStatus(c2, "disabled", "closed")
    verifyPointStatus(p1,  "unknown")
    verifyPointStatus(p2,  "disabled")
    verifyPointStatus(p3,  "unknown")
    verifyPointStatus(p4,  "unknown")
    verifyPointStatus(p5,  "fault")
    verifyPointStatus(p6,  "disabled")
    verifyPointStatus(p7,  "disabled")
    verifyPointStatus(p8,  "disabled")
    verifyPointStatus(p9,  "disabled")
    verifyPointStatus(p10, "fault")

    // disable/enable points
    p1 = commit(p1, ["disabled":m])
    p2 = commit(p2, ["disabled":None.val])
    verifyPointStatus(p1, "disabled")
    verifyPointStatus(p2, "unknown")

    // update fault condition
    p1 = commit(p1, ["kind":None.val])
    p2 = commit(p2, ["kind":None.val])
    verifyPointStatus(p1, "fault")
    verifyPointStatus(p2, "fault")

    // revert fault condition
    p1 = commit(p1, ["kind":"Number"])
    p2 = commit(p2, ["kind":"Number"])
    verifyPointStatus(p1, "disabled")
    verifyPointStatus(p2, "unknown")

    // now open
    c1.ping.get
    sync(c1)
    verifyConnStatus(c1, "ok", "open")
    verifyPointStatus(p1,  "disabled")
    verifyPointStatus(p2,  "unknown")
    verifyPointStatus(p3,  "unknown")
    verifyPointStatus(p4,  "unknown")
    verifyPointStatus(p5,  "fault")

    // now sync cur
    c1.syncCur(c1.points).get
    sync(c1)
    verifyConnStatus(c1, "ok", "open")
    verifyPointStatus(p1, "disabled")
    verifyPointStatus(p2, "ok",   "unknown")
    verifyPointStatus(p3, "down", "unknown")
    verifyPointStatus(p4, "ok",   "unknown")
    verifyPointStatus(p5, "fault")

    // issue point write
    waitForSteadyState
    proj.exts.point.pointWrite(p1, n(123), 13, "test").get
    proj.exts.point.pointWrite(p2, n(123), 14, "test").get
    proj.exts.point.pointWrite(p3, n(-123), 15, "test").get
    sync(c1)
    verifyConnStatus(c1, "ok", "open")
    verifyPointStatus(p1, "disabled")
    verifyPointStatus(p2, "ok",   "ok")
    verifyPointStatus(p3, "down", "down")
    verifyPointStatus(p4, "ok",   "unknown")
    verifyPointStatus(p5, "fault")
  }

  Void verifyConnStatus(Conn c, Str status, Str state)
  {
    proj.sync
    c.sync
    r := proj.db.readById(c.id)
    verifyEq(c.status.name, status)
    verifyEq(c.state.name, state)
    verifyEq(r["connStatus"], status)
    verifyEq(r["connState"], state)
  }

  Void verifyPointStatus(Dict rec, Str curStatus, Str writeStatus := curStatus, Str hisStatus := curStatus)
  {
    proj.sync
    ConnPoint pt := proj.exts.conn.point(rec.id)
    pt.conn.sync
    rec = proj.db.readById(rec.id)
    // echo("-- $pt.rec.dis curStatus=" + rec["curStatus"] + " writeStatus=" + rec["writeStatus"])

    verifyEq(rec["curStatus"],   rec.has("connTestCur")   ? curStatus : null)
    verifyEq(rec["writeStatus"], rec.has("connTestWrite") ? writeStatus : null)
    //verifyEq(rec["hisStatus"],   rec.has("connTestHis")   ? status : null)

    verifyEq(pt.isCurEnabled,   rec.has("connTestCur")   && pt.isEnabled && curStatus != "fault")
    verifyEq(pt.isWriteEnabled, rec.has("connTestWrite") && pt.isEnabled && writeStatus != "fault")
    verifyEq(pt.isHisEnabled,   rec.has("connTestHis")   && pt.isEnabled && hisStatus != "fault")
  }

//////////////////////////////////////////////////////////////////////////
// Writes
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testWrites()
  {
    lib := (ConnTestExt)addExt("hx.test.conn")
    cr := addRec(["dis":"C1", "connTestConn":m])
    p1 := addRec(["dis":"P1", "point":m, "writable":m, "connTestWrite":"1", "connTestConnRef":cr.id, "kind":"Number"])
    p2 := addRec(["dis":"P2", "point":m, "writable":m, "connTestWrite":"2", "connTestConnRef":cr.id, "kind":"Number"])
    p3 := addRec(["dis":"P3", "point":m, "writable":m, "connTestWrite":"3", "connTestConnRef":cr.id, "kind":"Number"])
    forceSteadyState
    proj.sync
    c := lib.conn(cr.id)

    // force open before enabling trace
    c.ping.get
    sync(c)
    c.trace.enable

    // send couple of sync writes
    3.times |i|
    {
      c.trace.clear
      proj.exts.point.pointWrite(p1, n(i), 16, "test").get
      sync(c)
      verifyWrite(p1, "ok", n(i), 16)
      verifyTrace(c, [
        ["dispatch", "write", |x| { verifyWriteMsg(x, p1, n(i)) }],
        ])
    }

    // now verify coalescing of write messages
    c.trace.clear
    c.send(HxMsg("sleep", 100ms))
    10.times |i|
    {
      proj.exts.point.pointWrite(p1, n(100+i), 16, "test").get
      proj.exts.point.pointWrite(p2, n(200+i), 16, "test").get
      proj.exts.point.pointWrite(p3, n(300+i), 16, "test").get
    }
    c.sync
    proj.exts.point.pointWrite(p1, n(109), 16, "test").get
    proj.exts.point.pointWrite(p2, n(209), 16, "test").get
    proj.exts.point.pointWrite(p3, n(309), 16, "test").get
    verifyTrace(c, [
      ["dispatch", "sleep", HxMsg("sleep", 100ms)],
      ["dispatch", "write", |x| { verifyWriteMsg(x, p1, n(109)) }],
      ["dispatch", "write", |x| { verifyWriteMsg(x, p2, n(209)) }],
      ["dispatch", "write", |x| { verifyWriteMsg(x, p3, n(309)) }],
    ])
  }

  Void verifyWrite(Dict rec, Str status, Obj? val, Int level)
  {
    rec = readById(rec.id)
    // echo("-- $rec.dis " + rec["writeStatus"] + " " + rec["writeVal"] + " @ " + rec["writeLevel"])
    verifyEq(rec["writeStatus"], status)
    verifyEq(rec["writeVal"],    val)
    verifyEq(rec["writeLevel"],  n(level))
  }

  Void verifyWriteMsg(HxMsg msg, Dict pt, Obj val)
  {
    info := (ConnWriteInfo)msg.b
    verifyEq(msg.id, "write")
    verifyEq(msg.a, proj.exts.conn.point(pt.id))
    verifyEq(info.val, val)
  }

//////////////////////////////////////////////////////////////////////////
// Dup Conns
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testDupConns()
  {
    addExt("hx.conn")
    addExt("hx.haystack")
    addExt("hx.obix")

    chId := addRec(["dis":"HC", "haystackConn":m]).id
    coId := addRec(["dis":"OC", "obixConn":m]).id

    ptags := ["point":m, "haystackPoint":m, "haystackConnRef":chId, "obixPoint":m, "obixConnRef":coId]
    p1Id := addRec(ptags.dup.addAll(["dis":"P1", "connDupPref":"hx.haystack"])).id
    p2Id := addRec(ptags.dup.addAll(["dis":"P2", "connDupPref":"hx.obix"])).id

    forceSteadyState
    proj.sync

    // lookup connectors
    iconn := proj.exts.conn
    Conn ch := iconn.conn(chId); verifyEq(ch.ext.name, "hx.haystack")
    Conn co := iconn.conn(coId); verifyEq(co.ext.name, "hx.obix")

    // lookup haystack version of points
    p1h := ch.point(p1Id); verifySame(p1h.conn, ch)
    p2h := ch.point(p2Id); verifySame(p2h.conn, ch)

    // lookup obix version of points
    p1o := co.point(p1Id); verifySame(p1o.conn, co)
    p2o := co.point(p2Id); verifySame(p1o.conn, co)

    // verify proj wide lookup based on pref
    verifyEq(iconn.point(p1Id).ext.name, "hx.haystack")
    verifyEq(iconn.point(p2Id).ext.name, "hx.obix")
    verifySame(iconn.point(p1Id), p1h)
    verifySame(iconn.point(p2Id), p2o)

    // verify details
    verifyDupDetails("""connDetails($p1Id.toCode)""", "HaystackExt")
    verifyDupDetails("""connDetails($p2Id.toCode)""", "ObixExt")
    verifyDupDetails("""connPointsVia($p1Id.toCode, "hx.haystack").connDetails""", "HaystackExt")
    verifyDupDetails("""connPointsVia($p2Id.toCode, "hx.haystack").connDetails""", "HaystackExt")
    verifyDupDetails("""connPointsVia($p1Id.toCode, "hx.obix").connDetails""", "ObixExt")
    verifyDupDetails("""connPointsVia($p2Id.toCode, "hx.obix").connDetails""", "ObixExt")
    verifyDupDetails("""readById($p1Id.toCode).connPointsVia($chId.toCode).connDetails""", "HaystackExt")
    verifyDupDetails("""readById($p2Id.toCode).connPointsVia($chId.toCode).connDetails""", "HaystackExt")
    verifyDupDetails("""readByIds([$p1Id.toCode]).connPointsVia($coId.toCode).connDetails""", "ObixExt")
    verifyDupDetails("""readByIds([$p2Id.toCode]).connPointsVia($coId.toCode).connDetails""", "ObixExt")
  }

  private Void verifyDupDetails(Str expr, Str contains)
  {
    details := makeContext.eval(expr).toStr
    // echo("--- $expr"); echo(details)
    verify(details.contains(contains))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void waitForSteadyState()
  {
    while (!proj.isSteadyState) Actor.sleep(10ms)
  }

  Void sync(Obj? c)
  {
    proj.sync
    if (c == null) return
    if (c is Conn)
      ((Conn)c).sync
    else
      ((Conn)proj.exts.conn.conn(Etc.toId(c))).sync
  }

}

