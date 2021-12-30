//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2021  Brian Frank  Creation
//

using concurrent
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

  @HxRuntimeTest
  Void testModel()
  {
    addLib("conn")
    verifyModel("haystack", "haystack", "lcwhx")
  }

  Void verifyModel(Str libName, Str prefix, Str flags)
  {
    lib := (ConnLib)rt.libs.add(libName)
    lib.spi.sync

    m := lib.model
    verifyEq(m.name, libName)
    verifyEq(m.connTag, prefix+"Conn")
    verifyEq(m.connRefTag, prefix+"ConnRef")

    verifyEq(m.hasLearn,    flags.contains("l"), "$libName learn")
    verifyEq(m.hasCur,      flags.contains("c"), "$libName cur")
    verifyEq(m.hasWrite,    flags.contains("w"), "$libName write")
    verifyEq(m.hasHis,      flags.contains("h"), "$libName his")

    verifyEq(m.writeLevelTag !== null, flags.contains("x"), "$libName writeLevel")
  }

//////////////////////////////////////////////////////////////////////////
// Service
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testService()
  {
    verifyNilService
    verifyEq(rt.conns.list.size, 0)

    addLib("haystack")
    verifyEq(rt.conns.list.size, 1)
    verifyConnService("haystack", "chwl")

    addLib("sql")
    verifyEq(rt.conns.list.size, 2)
    verifyConnService("haystack", "chwl")
    verifyConnService("sql", "h")
  }

  private Void verifyNilService()
  {
    c := rt.conns
    verifyEq(c.typeof.name, "NilConnRegistryService")
    verifyEq(c.list.size, 0)

    name := "haystack"
    verifyEq(c.byName(name, false), null)
    verifyErr(Err#) { c.byName(name) }
    verifyErr(Err#) { c.byName(name, true) }

    conn := Etc.emptyDict
    verifyEq(c.byConn(conn, false), null)
    verifyErr(Err#) { c.byConn(conn) }
    verifyErr(Err#) { c.byConn(conn, true) }

    pt := Etc.emptyDict
    verifyEq(c.byPoint(pt, false), null)
    verifyErr(Err#) { c.byPoint(pt) }
    verifyErr(Err#) { c.byPoint(pt, true) }
  }

  private HxConnService verifyConnService(Str name, Str flags)
  {
    c := rt.conns
    x := c.byName(name)
    verify(c.list.containsSame(x))
    verify(rt.services.getAll(HxConnService#).contains(x))

    verifyEq(x.name, name)
    verifyEq(x.connTag,    "${name}Conn")
    verifyEq(x.connRefTag, "${name}ConnRef")
    verifyEq(x.pointTag,   "${name}Point")
    verifyEq(x.curTag,     flags.contains("c") ? "${name}Cur" : null)
    verifyEq(x.hisTag,     flags.contains("h") ? "${name}His" : null)
    verifyEq(x.writeTag,   flags.contains("w") ? "${name}Write" : null)
    verifyEq(x.hasCur,     flags.contains("c"))
    verifyEq(x.hasHis,     flags.contains("h"))
    verifyEq(x.hasWrite,   flags.contains("w"))
    verifyEq(x.hasLearn,   flags.contains("l"))

    conn := Etc.makeDict(["id":Ref.gen, "${name}Conn":m])
    verifySame(c.byConn(conn), x)

    pt := Etc.makeDict(["${name}ConnRef":conn.id])
    verifySame(c.byPoint(pt), x)
    verifySame(c.byPoints([pt]), x)

    return x
  }

//////////////////////////////////////////////////////////////////////////
// Trace
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testTrace()
  {
    // empty roster
    lib := (ConnLib)addLib("haystack")
    rec := addRec(["dis":"Test Conn", "haystackConn":m])
    rt.sync
    c := lib.conn(rec.id)

    // start off empty
    verifyEq(c.trace.isEnabled, false)
    verifyTrace(c, [,])

    // write a trace while disalbed
    c.trace.write("foo", "msg", null)
    verifyTrace(c, [,])

    // now enable it
    c.trace.enable
    verifyEq(c.trace.isEnabled, true)
    c.trace.write("foo", "msg", null)
    verifyTrace(c, [
      ["foo", "msg", null],
      ], false)

    // write some other traces
    c.trace.dispatch(HxMsg("x"))
    c.trace.req("req test", "req body")
    c.trace.res("res test", "res body")
    c.trace.event("event test", "event body")
    verifyTrace(c, [
      ["foo",      "msg",        null],
      ["dispatch", "x",          HxMsg("x")],
      ["req",      "req test",   "req body"],
      ["res",      "res test",   "res body"],
      ["event",    "event test", "event body"],
      ], false)

    // verify re-enable doesn't change anything
    c.trace.enable
    verifyEq(c.trace.isEnabled, true)
    verifyTrace(c, [
      ["foo",      "msg",        null],
      ["dispatch", "x",          HxMsg("x")],
      ["req",      "req test",   "req body"],
      ["res",      "res test",   "res body"],
      ["event",    "event test", "event body"],
      ], false)

    // disable
    c.trace.disable
    verifyEq(c.trace.isEnabled, false)
    verifyTrace(c, [,], false)
    c.trace.write("ignore", "ignore")
    verifyTrace(c, [,], false)

    // buf test
    c.trace.enable
    buf := "buf test".toBuf
    verifyErr(NotImmutableErr#) { c.trace.req("bad", buf) }
    buf = buf.toImmutable
    c.trace.req("req test", buf)
    verify(buf.bytesEqual("buf test".toBuf))
  }

  Void verifyTrace(Conn c, Obj[] expected, Bool sync := true)
  {
    if (sync) c.sync
    actual := c.trace.read
    if (sync && c.trace.isEnabled) actual = actual[0..-2] // strip trailing sync
    // echo("\n --- trace ---"); echo(actual.join("\n"))
    verifyEq(actual.size, expected.size)
    actual.each |a, i|
    {
      e := (Obj?[]) expected[i]
      verifyEq(a.ts.date, Date.today)
      verifyEq(a.type, e[0])
      verifyEq(a.msg,  e[1])
      verifyEq(a.arg,  e[2])
    }
  }

//////////////////////////////////////////////////////////////////////////
// Roster
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testRoster()
  {
    // empty roster
    lib := (ConnLib)addLib("haystack")
    verifyRoster(lib, [,])

    // add connector
    c1 := addRec(["dis":"C1", "haystackConn":m])
    rt.sync
    verifyRoster(lib,
      [
       [c1],
      ])

    // add two more
    c2 := addRec(["dis":"C2", "haystackConn":m])
    c3 := addRec(["dis":"C3", "haystackConn":m])
    rt.sync
    verifyRoster(lib,
      [
       [c1],
       [c2],
       [c3],
      ])

    // modify c2
    c2 = commit(c2, ["change":m, "dis":"C2x"])
    rt.sync
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

    // add some points
    p1a := addRec(["dis":"1A", "point":m, "haystackConnRef":c1.id])
    p1b := addRec(["dis":"1B", "point":m, "haystackConnRef":c1.id])
    p1c := addRec(["dis":"1C", "point":m, "haystackConnRef":c1.id])
    p2a := addRec(["dis":"2A", "point":m, "haystackConnRef":c2.id])
    rt.sync
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
    rt.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1b, p1c],
       [c2, p2a],
       [c3],
      ])
    verifyTrace(conn1, [
      ["dispatch", "pointUpdated", HxMsg("pointUpdated", conn1.point(p1b.id))],
      ])

    // move pt to new connector
    conn1.trace.clear
    conn3.trace.clear
    p1bOld := conn1.point(p1b.id)
    p1b = commit(p1b, ["dis":"3A", "haystackConnRef":c3.id])
    rt.sync
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

    // create some points which don't map to connectors yet
    c4id := Ref("c4")
    p4a := addRec(["dis":"4A", "point":m, "haystackConnRef":c4id])
    p4b := addRec(["dis":"4B", "point":m, "haystackConnRef":"bad ref"])
    rt.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
      ])

    // now add c4
    c4 := addRec(["id":c4id, "dis":"C4", "haystackConn":m])
    verifyEq(c4.id, c4id)
    rt.sync
    conn4 := lib.conn(c4.id)
    conn4.trace.enable
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
       [c4, p4a],
      ])

    // fix p4b which had bad ref
    p4b = commit(p4b, ["haystackConnRef":c4.id])
    rt.sync
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

    // remove points
    p4aOld := conn4.point(p4a.id)
    p4bOld := conn4.point(p4b.id)
    conn4.trace.clear
    p4a = commit(p4a, ["point":Remove.val])
    p4b = commit(p4b, ["trash":m])
    rt.sync
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

    // add them back
    conn4.trace.clear
    p4a = commit(p4a, ["point":m])
    p4b = commit(p4b, ["trash":Remove.val])
    rt.sync
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

    // remove c2 and c3
    c2 = commit(c2, ["haystackConn":Remove.val])
    c3 = commit(c3, ["trash":m])
    rt.sync
    verifyErr(UnknownConnErr#) { lib.conn(c2.id) }
    verifyErr(UnknownConnErr#) { lib.conn(c3.id, true) }
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c4, p4a, p4b],
      ])

    // add back c2 and c3
    c2 = commit(c2, ["haystackConn":m])
    c3 = commit(c3, ["trash":Remove.val])
    rt.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
       [c4, p4a, p4b],
      ])

    // now restart lib
    rt.libs.remove(lib)
    lib = addLib("haystack")
    rt.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
       [c4, p4a, p4b],
      ])
  }

  Void verifyRoster(ConnLib lib, Dict[][] expected)
  {
    // echo; lib->roster->dump
    conns := lib.conns.dup.sort |a, b| { a.dis <=> b.dis }
    verifyEq(conns.size, expected.size)
    exAllPoints := Dict[,]

    // each connector
    conns.each |c, i|
    {
      // expected rows are a list where first item is connector rec
      // and rest of list is the expected points under that connector
      ex    := expected[i]
      exRec := ex[0]
      exPts := ex[1..-1]
      exAllPoints.addAll(exPts)

      // connector
      verifySame(c.lib, lib)
      verifySame(c.rec, exRec)
      verifyEq(c.id, exRec.id)
      verifyEq(c.dis, exRec.dis)
      verifySame(lib.conn(exRec.id), c)

      // points
      verifyPoints(lib, c.points, exPts, false)
      c.points.each |pt| { verifySame(pt.conn, c) }

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

  Void verifyPoints(ConnLib lib, ConnPoint[] actual, Dict[] expected, Bool sort)
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
      verifySame(a.rec, e)
      verifyEq(a.id, id)
      verifyEq(a.dis, e.dis)
      verifySame(lib.point(id), a)
      verifySame(a.conn.point(id), a)

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

}