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
    proj.sync
    ext.writeMgr.sync
    proj.db.sync

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

    // level 18 issues the output without occupying a priority array slot
    2.times
    {
      eval("pointWrite($ptId, 180, 18, \"test-18\")")
      g := verifyWrite(ext, pt, n(180), 18, [:])
      verifyEq(g.meta["writeVal"], n(180))
      verifyEq(g.meta["writeLevel"], n(18))
    }

    // ordinary takeover and release never fall back to the level 18 request
    eval("pointWrite($ptId, 50, 5, \"test-5\")")
    verifyWrite(ext, pt, n(50), 5, [5:n(50)])
    eval("pointWrite($ptId, null, 5, \"test-5\")")
    verifyWrite(ext, pt, null, 17, [:])

    // every ordinary level masks and discards level 18; release never falls back to 18
    (1..17).each |level|
    {
      who := level == 1 || level == 8 || level == 17 ? eval("context()->username").toStr : "test-$level"
      eval("pointWrite($ptId, 100, $level, $who.toCode)")
      eval("pointWrite($ptId, 180, 18, \"test-18\")")
      verifyWrite(ext, pt, n(100), level, [level:n(100)])
      eval("pointWrite($ptId, 181, 18, \"masked-18\")")
      verifyWrite(ext, pt, n(100), level, [level:n(100)])
      eval("pointWrite($ptId, null, $level, $who.toCode)")
      verifyWrite(ext, pt, null, 17, [:])
    }

    // null level 18 leaves a higher priority effective and occupies no array slot
    eval("pointWrite($ptId, 50, 5, \"test-5\")")
    eval("pointWrite($ptId, 180, 18, \"test-18\")")
    verifyWrite(ext, pt, n(50), 5, [5:n(50)])
    eval("pointWrite($ptId, null, 18, \"clear-18\")")
    verifyWrite(ext, pt, n(50), 5, [5:n(50)])
    eval("pointWrite($ptId, null, 5, \"test-5\")")
    verifyWrite(ext, pt, null, 17, [:])

    // null level 18 after an effective request returns to level 17
    eval("pointWrite($ptId, 180, 18, \"test-18\")")
    verifyWrite(ext, pt, n(180), 18, [:])
    eval("pointWrite($ptId, null, 18, \"clear-18\")")
    verifyWrite(ext, pt, null, 17, [:])

    // Boolean and string requests also issue outputs without retaining array values
    ["Bool":true, "Str":"command"].each |value, kind|
    {
      p := addRec(["dis":kind, "point":m, "writable":m, "kind":kind])
      proj.sync
      2.times
      {
        ext.pointWrite(p, value, 18, "test-18").get
        verifyWrite(ext, p, value, 18, [:])
      }
    }

    verifyErr(Err#) { ext.pointWrite(pt, n(1), 0, "test") }
    verifyErr(Err#) { ext.pointWrite(pt, n(1), 19, "test") }

    // level 18 output is transient and is not restored after restart
    eval("pointWrite($ptId, 180, 18, \"test-18\")")
    verifyWrite(ext, pt, n(180), 18, [:])
    projRestart
    ext = proj.exts.get("hx.point")
    ext.spi.sync
    proj.sync
    ext.writeMgr.sync
    proj.db.sync
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
    verifyEq(pt["write18"], null)

    // pointWriteArray
    Grid g := eval("pointWriteArray($pt.id.toCode)")
    verifyEq(g.size, 17)
    verifyEq(g.meta["writeVal"], val)
    verifyEq(g.meta["writeLevel"], n(level))
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
    z := addRec(["dis":"Z", "point":m, "writable":m, "kind":"Number"])

    obsA := TestObserver()
    obsB := TestObserver()
    obsX := TestObserver()
    obsY := TestObserver()
    obsZ := TestObserver()

    proj.obs.get("obsPointWrites").subscribe(obsA, Etc.makeDict([:]))
    proj.obs.get("obsPointWrites").subscribe(obsB, Etc.makeDict(["obsAllWrites":m]))
    proj.obs.get("obsPointWrites").subscribe(obsX, Etc.makeDict(["obsFilter":"dis==\"X\""]))
    proj.obs.get("obsPointWrites").subscribe(obsY, Etc.makeDict(["obsFilter":"dis==\"Y\""]))
    proj.obs.get("obsPointWrites").subscribe(obsZ, Etc.makeDict(["obsFilter":"dis==\"Z\""]))

    reset := |->|
    {
      proj.sync
      obsA.clear
      obsB.clear
      obsX.clear
      obsY.clear
      obsZ.clear
    }

    // verify no events received before steady state
    try
    {
      verifyEq(proj.isSteadyState, false)
      eval("pointWrite($x.id.toCode, 987, 16, \"test-16\")")
      eval("pointWrite($z.id.toCode, 180, 18, \"test-18\")")
      verifyWrite(ext, z, n(180), 18, [:])
      verifyObs(obsA, x, null, -1, "")
      verifyObs(obsB, x, null, -1, "")
      verifyObs(obsX, x, null, -1, "")
      verifyObs(obsY, y, null, -1, "")
      verifyObs(obsZ, z, null, -1, "")
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
    // Note: its indeterminate whether obsA/obsB received x, y, or z last
    verifyObs(obsX, x, n(987), 16, "first")
    verifyObs(obsY, y, null, 17, "first")
    verifyObs(obsZ, z, n(180), 18, "first")

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

    // level 18 is masked too; only allWrites observes the request
    reset()
    eval("pointWrite($x.id.toCode, 180, 18, \"test-18\")")
    verifyWrite(ext, x, n(789), 14, [14:n(789), 15:n(150), 16:n(123)])
    verifyObs(obsA, x, null, -1, "")
    verifyObs(obsB, x, n(180), 18, "test-18")
    verifyObs(obsX, x, null, -1, "")
    verifyObs(obsY, y, null, -1, "")

    // different and repeated masked requests notify allWrites and leave no array value
    2.times
    {
      reset()
      eval("pointWrite($x.id.toCode, 181, 18, \"masked-18\")")
      verifyWrite(ext, x, n(789), 14, [14:n(789), 15:n(150), 16:n(123)])
      verifyObs(obsA, x, null, -1, "")
      verifyObs(obsB, x, n(181), 18, "masked-18")
      verifyObs(obsX, x, null, -1, "")
      verifyObs(obsY, y, null, -1, "")
      verifyEq(obsB.msgs.size, 1)
    }

    // null level 15 (only allWrites obs receives event)
    reset()
    eval("pointWrite($x.id.toCode, null, 15, \"test-15\")")
    verifyWrite(ext, x, n(789), 14, [14:n(789), 16:n(123)])
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

    // null level 14 (all receive auto event; the level 18 request was discarded)
    eval("pointWrite($x.id.toCode, null, 14, \"test-14\")")
    verifyWrite(ext, x, null, 17, [:])
    verifyObs(obsA, x, null, 17, "test-14")
    verifyObs(obsB, x, null, 14, "test-14")
    verifyObs(obsX, x, null, 17, "test-14")
    verifyObs(obsY, y, null, -1, "")

    // repeated level 18 requests each issue an effective observation
    2.times
    {
      reset()
      eval("pointWrite($x.id.toCode, 180, 18, \"test-18\")")
      verifyWrite(ext, x, n(180), 18, [:])
      verifyObs(obsA, x, n(180), 18, "test-18")
      verifyObs(obsB, x, n(180), 18, "test-18")
      verifyObs(obsX, x, n(180), 18, "test-18")
      verifyEq(obsA.msgs.size, 1)
      verifyEq(obsB.msgs.size, 1)
    }

    // null level 18 after an effective request observes the ordinary null fallback
    reset()
    eval("pointWrite($x.id.toCode, null, 18, \"clear-18\")")
    verifyWrite(ext, x, null, 17, [:])
    verifyObs(obsA, x, null, 17, "clear-18")
    verifyObs(obsB, x, null, 18, "clear-18")
    verifyObs(obsX, x, null, 17, "clear-18")
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
  override Dict meta() { Etc.dict0 }
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

