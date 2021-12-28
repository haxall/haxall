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

    // update pt
    p1b = commit(p1b, ["dis":"1Bx", "change":"it"])
    rt.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1b, p1c],
       [c2, p2a],
       [c3],
      ])

    // move pt to new connector
    p1b = commit(p1b, ["dis":"3A", "haystackConnRef":c3.id])
    rt.sync
    verifyRoster(lib,
      [
       [c1, p1a, p1c],
       [c2, p2a],
       [c3, p1b],
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

    // remove points
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

    // add them back
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