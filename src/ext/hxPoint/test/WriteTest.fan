//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jul 2012  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using obs
using folio
using hx

**
** WriteTest
**
class WriteTest : HxTest
{

  @HxTestProj
  Void testWrites()
  {
    PointExt ext := addExt("hx.point")
    ext.spi.sync

    pt := addRec(["dis":"P", "point":m, "writable":m, "kind":"Number"])
    ptId := pt.id.toCode

    // initial state
    verifyWrite(ext, pt, null, 17, [:])

    // write def
    eval("pointSetDef($ptId, 170)")
    verifyWrite(ext, pt, n(170), 17, [17:n(170)])

    // level 14
    eval("pointWrite($ptId, 140, 14, \"test-14\")")
    verifyWrite(ext, pt, n(140), 14, [14: n(140), 17:n(170)])

    // manual 8
    eval("pointOverride($ptId, 88)")
    verifyWrite(ext, pt, n(88), 8, [8:n(88), 14: n(140), 17:n(170)])
    eval("pointOverride($ptId, 80)")
    verifyWrite(ext, pt, n(80), 8, [8:n(80), 14: n(140), 17:n(170)])

    // add curTracksWrite
    pt = proj.commit(Diff(proj.readById(pt.id), ["curTracksWrite":m])).newRec

    // emergency 1
    eval("pointEmergencyOverride($ptId, 10)")
    verifyWrite(ext, pt, n(10), 1, [1:n(10), 8:n(80), 14: n(140), 17:n(170)])

    // auto 1
    eval("pointEmergencyAuto($ptId)")
    verifyWrite(ext, pt, n(80), 8, [8:n(80), 14: n(140), 17:n(170)])

    // auto 8
    eval("pointAuto($ptId)")
    verifyWrite(ext, pt, n(140), 14, [14: n(140), 17:n(170)])

    // auto 14
    eval("pointWrite($ptId, null, 14, \"test-14\")")
    verifyWrite(ext, pt, n(170), 17, [17:n(170)])

    // auto def
    eval("pointSetDef($ptId, null)")
    verifyWrite(ext, pt, null, 17, [:])

  }

  Grid verifyWrite(PointExt ext, Dict pt, Obj? val, Int level, Int:Obj? levels)
  {
    proj.sync
    pt = proj.readById(pt.id)
    if (pt.missing("writeLevel"))
    {
      proj.db.sync
      pt = proj.readById(pt.id)
    }

    // echo("==> $val @ $level  ?=  " + pt["writeVal"] + " @ " + pt["writeLevel"] + " | " + pt["curVal"] + " @ " + pt["curStatus"])

    verifyEq(pt["writeVal"], val)
    verifyEq(pt["writeStatus"], null) // used by connectors
    verifyEq(pt["writeLevel"], Number(level))
    if (pt.has("curTracksWrite"))
    {
      verifyEq(pt["curVal"], val)
      verifyEq(pt["curStatus"], "ok")
    }
    else
    {
      verifyEq(pt["curVal"], null)
      verifyEq(pt["curStatus"], null)
    }

    // persistence tags
    verifyEq(pt["write1"], levels[1])
    verifyEq(pt["write8"], levels[8])
    verifyEq(pt["writeDef"], levels[17])

    // pointWriteArray
    Grid g := eval("pointWriteArray($pt.id.toCode)")
    verifyEq(g.size, 17)
    g.each |row, i|
    {
      lvl := i+1
      verifyEq(row->level, n(lvl))
      verifyEq(row["val"], levels[lvl])
      if (row.has("val"))
      {
        if (lvl == 1 || lvl == 8 || lvl == 17)
          verifyEq(row["who"], eval("context()->username"))
        else
          verifyEq(row["who"], "test-$lvl")
      }
    }

    verifyGridEq(g, proj.exts.point.pointArray(pt))

    return g
  }

//////////////////////////////////////////////////////////////////////////
// Observable
//////////////////////////////////////////////////////////////////////////

  @HxTestProj { meta = "steadyState: 500ms" }
  Void testObservable()
  {
    PointExt ext := addExt("hx.point")

    x := addRec(["dis":"X", "point":m, "writable":m, "kind":"Number"])
    y := addRec(["dis":"Y", "point":m, "writable":m, "kind":"Number"])

    obsA := TestObserver()
    obsB := TestObserver()
    obsX := TestObserver()
    obsY := TestObserver()

    proj.obs.get("obsPointWrites").subscribe(obsA, Etc.makeDict([:]))
    proj.obs.get("obsPointWrites").subscribe(obsB, Etc.makeDict(["obsAllWrites":m]))
    proj.obs.get("obsPointWrites").subscribe(obsX, Etc.makeDict(["obsFilter":"dis==\"X\""]))
    proj.obs.get("obsPointWrites").subscribe(obsY, Etc.makeDict(["obsFilter":"dis==\"Y\""]))

    reset := |->|
    {
      proj.sync
      obsA.clear
      obsB.clear
      obsX.clear
      obsY.clear
    }

    // verify no events received before steady state
    try
    {
      verifyEq(proj.isSteadyState, false)
      eval("pointWrite($x.id.toCode, 987, 16, \"test-16\")")

      verifyObs(obsA, x, null, -1, "")
      verifyObs(obsB, x, null, -1, "")
      verifyObs(obsX, x, null, -1, "")
      verifyObs(obsY, y, null, -1, "")
    }
    catch (TestErr e)
    {
      if (proj.isSteadyState)
      {
        echo("***WARN*** reached steady state before expected")
        return null
      }
      throw e
    }

    while (!proj.isSteadyState) Actor.sleep(10ms)
    proj.sync
    ext.writeMgr.forceCheck

    // verify first event
    // Note: its indeterminate whether obsA/obsB received x or y last
    verifyObs(obsX, x, n(987), 16, "first")
    verifyObs(obsY, y, null, 17, "first")

    // set level 123 @ 16
    reset()
    eval("pointWrite($x.id.toCode, 123, 16, \"test-16\")")
    verifyWrite(ext, x, n(123), 16, [16: n(123)])
    verifyObs(obsA, x, n(123), 16, "test-16")
    verifyObs(obsB, x, n(123), 16, "test-16")
    verifyObs(obsX, x, n(123), 16, "test-16")
    verifyObs(obsY, y, null, -1, "")

    // set level 456 @ 14
    reset()
    eval("pointWrite($x.id.toCode, 456, 14, \"test-14\")")
    verifyWrite(ext, x, n(456), 14, [14:n(456), 16: n(123)])
    verifyObs(obsA, x, n(456), 14, "test-14")
    verifyObs(obsB, x, n(456), 14, "test-14")
    verifyObs(obsX, x, n(456), 14, "test-14")
    verifyObs(obsY, y, null, -1, "")

    // change level 789 @ 14
    reset()
    eval("pointWrite($x.id.toCode, 789, 14, \"test-14\")")
    verifyWrite(ext, x, n(789), 14, [14:n(789), 16: n(123)])
    verifyObs(obsA, x, n(789), 14, "test-14")
    verifyObs(obsB, x, n(789), 14, "test-14")
    verifyObs(obsX, x, n(789), 14, "test-14")
    verifyObs(obsY, y, null, -1, "")

    // keep level 789 @ 14 (no events fired)
    reset()
    eval("pointWrite($x.id.toCode, 789, 14, \"test-14\")")
    verifyWrite(ext, x, n(789), 14, [14:n(789), 16: n(123)])
    verifyObs(obsA, x, null, -1, "")
    verifyObs(obsB, x, null, -1, "")
    verifyObs(obsX, x, null, -1, "")
    verifyObs(obsY, y, null, -1, "")

    // set 69 @ 13
    reset()
    eval("pointWrite($x.id.toCode, 69, 13, \"test-13\")")
    verifyWrite(ext, x, n(69), 13, [13: n(69), 14:n(789), 16: n(123)])
    verifyObs(obsA, x, n(69), 13, "test-13")
    verifyObs(obsB, x, n(69), 13, "test-13")
    verifyObs(obsX, x, n(69), 13, "test-13")
    verifyObs(obsY, y, null, -1, "")

    // now clear 13 (standard subs see effective change, obsAllWrites see 13 nulled out)
    reset()
    eval("pointWrite($x.id.toCode, null, 13, \"test-13\")")
    verifyWrite(ext, x, n(789), 14, [14:n(789), 16: n(123)])
    verifyObs(obsA, x, n(789), 14, "test-13")
    verifyObs(obsB, x, null,   13, "test-13")
    verifyObs(obsX, x, n(789), 14, "test-13")
    verifyObs(obsY, y, null, -1, "")

    // change level 150 @ 15 (only allWrites obs receives event)
    reset()
    eval("pointWrite($x.id.toCode, 150, 15, \"test-15\")")
    verifyWrite(ext, x, n(789), 14, [14:n(789), 15:n(150), 16: n(123)])
    verifyObs(obsA, x, null, -1, "")
    verifyObs(obsB, x, n(150), 15, "test-15")
    verifyObs(obsX, x, null, -1, "")
    verifyObs(obsY, y, null, -1, "")

    // null level 15 (only allWrites obs receives event)
    reset()
    eval("pointWrite($x.id.toCode, null, 15, \"test-15\")")
    verifyWrite(ext, x, n(789), 14, [14:n(789), 16: n(123)])
    verifyObs(obsA, x, null, -1, "")
    verifyObs(obsB, x, null, 15, "test-15")
    verifyObs(obsX, x, null, -1, "")
    verifyObs(obsY, y, null, -1, "")

    // null level 16 (only allWrites obs receives event)
    eval("pointWrite($x.id.toCode, null, 16, \"test-16\")")
    verifyWrite(ext, x, n(789), 14, [14:n(789)])
    verifyObs(obsA, x, null, -1, "")
    verifyObs(obsB, x, null, 16, "test-16")
    verifyObs(obsX, x, null, -1, "")
    verifyObs(obsY, y, null, -1, "")

    // null level 14 (all receive auto event)
    eval("pointWrite($x.id.toCode, null, 14, \"test-14\")")
    verifyWrite(ext, x, null, 17, [:])
    verifyObs(obsA, x, null, 17, "test-14")
    verifyObs(obsB, x, null, 14, "test-14")
    verifyObs(obsX, x, null, 17, "test-14")
    verifyObs(obsY, y, null, -1, "")
  }

  private Void verifyObs(TestObserver obs, Dict pt, Obj? val, Int level, Str who)
  {
    e := obs.sync as Dict
    // echo("  verifyObj $obs | $e")
    if (level == -1)
    {
      verifyNull(e, null)
      return
    }
    else
    {
      if (e == null) fail("no event received")
    }
    verifyEq(e->type, "obsPointWrites")
    verifyEq(e->id, pt.id)
    verifyDictEq(e->rec, pt)
    verifyEq(e["val"], val)
    verifyEq(e->level, n(level))
    verifyEq(e->who, who)

    if (who == "first")
    {
      verifyEq(e->first, m)
      verifyEq(e.has("first"), true)
    }
    else
    {
      verifyEq(e["first"], null)
      verifyEq(e.has("first"), false)
    }
  }
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
  Void clear() { sync; msgsRef.val = Obj#.emptyList }
  const AtomicRef msgsRef := AtomicRef(Obj#.emptyList)
}

