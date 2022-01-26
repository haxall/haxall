//
// Copyright (c) 2014, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Aug 2014  Brian Frank  Creation
//   25 Jan 2022  Brian Frank  Refactor for Haxall
//

using concurrent
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
    fw  := (ConnFwLib)addLib("conn")
    lib := (ConnLib)addLib("haystack")

    // verify tuning registry in ConnFwLib
    verifyTunings(fw, [t1, t2, t3])
    t4 := addRec(["connTuning":m, "dis":"T-4", "staleTime":n(4, "sec")])
    verifyTunings(fw, [t1, t2, t3, t4])
    t4Old := fw.tunings.get(t4.id)
    t4 = commit(t4, ["dis":"T-4 New", "staleTime":n(44, "sec")])
    verifyTunings(fw, [t1, t2, t3, t4])
    verifySame(fw.tunings.get(t4.id), t4Old)
    t4 = commit(t4, ["connTuning":Remove.val])
    verifyTunings(fw, [t1, t2, t3])

    // verify ConnLib, Conn, ConnPoint tuning....

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
    rt.libs.remove("haystack")
    rt.libs.remove("conn")
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
    verifyDictEq(lib.point(pt.id).tuning.rec, Etc.makeDict1("id", t5id))

    // now fill in t5
    t5 := addRec(["id":t5id, "dis":"T-5", "connTuning":m, "staleTime":n(123, "sec")])
    sync(c)
    verifyEq(fw.tunings.get(t5id).staleTime, 123sec)
    verifyEq(lib.point(pt.id).tuning.id, t5.id)
    verifyEq(lib.point(pt.id).tuning.staleTime, 123sec)
    verifySame(lib.point(pt.id).tuning.rec, t5)
  }

  Void verifyTunings(ConnFwLib fw, Dict[] expected)
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

  Void verifyTuning(ConnFwLib fw, ConnLib lib, Dict ptRec, Dict tuningRec, Duration staleTime)
  {
    pt := lib.point(ptRec.id)
    t  := fw.tunings.get(tuningRec.id)
    verifySame(pt.tuning, t)
    verifyEq(pt.tuning.staleTime, staleTime)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void sync(Obj? c)
  {
    rt.sync
    if (c == null) return
    if (c is Conn)
      ((Conn)c).sync
    else
      ((Conn)rt.conn.conn(Etc.toId(c))).sync
  }
}