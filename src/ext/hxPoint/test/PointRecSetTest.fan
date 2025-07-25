//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Mar 2022  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using axon
using folio
using hx

**
** PointRecSetTest
**
class PointRecSetTest : HxTest
{

  @HxTestProj
  Void testSets()
  {
    // ext
    addLib("hx.point")

    // sites
    siteA := addRec(["dis":"Site A", "site":m, "geoCity":"Richmond"])
    siteB := addRec(["dis":"Site B", "site":m, "geoCity":"Norfolk"])

    // spaces
    spAP := addRec(["dis":"Space AP", "siteRef":siteA.id, "space":m, "siteA":m])
    spAQ := addRec(["dis":"Space AQ", "siteRef":siteA.id, "space":m, "siteA":m])
    spBR := addRec(["dis":"Space BR", "siteRef":siteB.id, "space":m, "siteB":m])

    // equip
    eqA1 := addRec(["dis":"Eq A1", "siteRef":siteA.id, "spaceRef":spAP.id, "equip":m, "siteA":m])
    eqA2 := addRec(["dis":"Eq A2", "siteRef":siteA.id, "spaceRef":spAQ.id, "equip":m, "siteA":m])
    eqB1 := addRec(["dis":"Eq B1", "siteRef":siteB.id, "spaceRef":spBR.id, "equip":m, "siteB":m])

    // devices
    dvA1a := addRec(["dis":"Dv A1a", "siteRef":siteA.id, "spaceRef":spAP.id, "device":m, "siteA":m])
    dvA1b := addRec(["dis":"Dv A1b", "siteRef":siteA.id, "spaceRef":spAP.id, "device":m, "siteA":m])
    dvB1  := addRec(["dis":"Dv B1",  "siteRef":siteB.id, "spaceRef":spBR.id, "equipRef":eqB1.id, "device":m, "siteB":m])

    // points
    ptAa  := addRec(["dis":"Pt Aa",  "siteRef":siteA.id, "point":m])
    ptA1a := addRec(["dis":"Pt A1a", "siteRef":siteA.id, "spaceRef":spAP.id, "equipRef":eqA1.id, "deviceRef":dvA1a.id, "point":m, "siteA":m])
    ptA1b := addRec(["dis":"Pt A1b", "siteRef":siteA.id, "spaceRef":spAP.id, "equipRef":eqA1.id, "deviceRef":dvA1b.id, "point":m, "siteA":m])
    ptA2a := addRec(["dis":"Pt A2a", "siteRef":siteA.id, "spaceRef":spAQ.id, "equipRef":eqA2.id, "point":m, "siteA":m])
    ptB1a := addRec(["dis":"Pt B1a", "siteRef":siteB.id, "spaceRef":spBR.id, "equipRef":eqB1.id, "point":m, "siteB":m])
    ptB1b := addRec(["dis":"Pt B1b", "siteRef":siteB.id, "spaceRef":spBR.id, "equipRef":eqB1.id, "deviceRef":dvB1.id, "point":m, "siteB":m])

    // toSites

    verifyToSet("readAll(ext).toSites",   [,])
    verifyToSet("readAll(site).toSites",  [siteA, siteB])
    verifyToSet("readById($siteB.id.toCode).toSites",  [siteB])
    verifyToSet("readAll(dis).toSites",   [siteA, siteB])
    verifyToSet("readAll(equip).toSites", [siteA, siteB])
    verifyToSet("read(equip and siteB).toSites", [siteB])
    verifyToSet("readAll(point).toSites", [siteA, siteB])
    verifyToSet("readAll(point).toSites", [siteA, siteB])
    verifyToSet("readAll(point and siteA).toSites", [siteA])
    verifyToSet("readAll(point and siteB).toSites", [siteB])
    verifyToSet("[@$siteA.id, @$eqA1.id].toSites", [siteA])
    verifyToSet("[@$siteA.id, @$ptB1b.id].toSites", [siteA, siteB])

    // toSpaces

    verifyToSet("toSpaces(null)",    [,])
    verifyToSet("readAll(ext).toSpaces",    [,])
    verifyToSet("readById($spAP.id.toCode).toSpaces",  [spAP])
    verifyToSet("readAll(dis).toSpaces",    [spAP, spAQ, spBR])
    verifyToSet("readAll(site).toSpaces",   [spAP, spAQ, spBR])
    verifyToSet("readAll(space).toSpaces",  [spAP, spAQ, spBR])
    verifyToSet("readAll(equip).toSpaces",  [spAP, spAQ, spBR])
    verifyToSet("readAll(point).toSpaces",   [spAP, spAQ, spBR])
    verifyToSet("readAll(point and siteA).toSpaces", [spAP, spAQ])
    verifyToSet("readAll(point and siteB).toSpaces", [spBR])
    verifyToSet("readAll(id==$siteA.id.toCode).toSpaces", [spAP, spAQ])
    verifyToSet("readById($siteB.id.toCode).toSpaces", [spBR])
    verifyToSet("[@$spAQ.id, @$siteB.id].toSpaces", [spAQ, spBR])
    verifyToSet("[@$eqA2.id, @$siteB.id].toSpaces", [spAQ, spBR])

    // toEquips

    verifyToSet("readAll(ext).toEquips",    [,])
    verifyToSet("readById($eqA2.id.toCode).toEquips",  [eqA2])
    verifyToSet("readAll(equip).toEquips",  [eqA1, eqA2, eqB1])
    verifyToSet("readAll(dis).toEquips",    [eqA1, eqA2, eqB1])
    verifyToSet("readAll(equip and siteRef==$siteA.id.toCode).toEquips",  [eqA1, eqA2])
    verifyToSet("readAll(point).toEquips",   [eqA1, eqA2, eqB1,])
    verifyToSet("readAll(point and siteA).toEquips", [eqA1, eqA2])
    verifyToSet("readAll(point and siteB).toEquips", [eqB1])
    verifyToSet("readAll(site).toEquips",   [eqA1, eqA2, eqB1])
    verifyToSet("readAll(id==$siteA.id.toCode).toEquips", [eqA1, eqA2])
    verifyToSet("readById($siteB.id.toCode).toEquips", [eqB1])
    verifyToSet("[@$spAQ.id].toEquips", [eqA2])
    verifyToSet("[@$spAP.id, @$eqB1.id].toEquips", [eqA1, eqB1])
    verifyToSet("[@$ptB1b.id].toEquips", [eqB1])
    verifyToSet("[@$ptB1b.id, @$spBR.id].toEquips", [eqB1])

    // toDevices

    verifyToSet("readAll(ext).toDevices",    [,])
    verifyToSet("readById($ptA1b.id.toCode).toDevices",  [dvA1b])
    verifyToSet("readAll(point).toDevices",  [dvA1a, dvA1b, dvB1])
    verifyToSet("readAll(dis).toDevices",  [dvA1a, dvA1b, dvB1])
    verifyToSet("readAll(point and siteB).toDevices",  [dvB1])
    verifyToSet("readAll(site).toDevices",  [dvA1a, dvA1b, dvB1])
    verifyToSet("readAll(space).toDevices",  [dvA1a, dvA1b, dvB1])
    verifyToSet("readAll(device and siteB).toDevices",  [dvB1])
    verifyToSet("readAll(device and siteB).toDevices",  [dvB1])
    verifyToSet("readAll(id==$siteA.id.toCode).toDevices", [dvA1a, dvA1b])
    verifyToSet("(@$spAP.id).toDevices", [dvA1a, dvA1b])
    verifyToSet("(@$spAQ.id).toDevices", [,])
    verifyToSet("[@$spAP.id, @$siteB.id].toDevices", [dvA1a, dvA1b, dvB1])
    verifyToSet("[@$ptA1a.id, @$dvB1.id].toDevices", [dvA1a, dvB1])

    // toPoints

    verifyToSet("readById($eqA1.id.toCode).toPoints", [ptA1a, ptA1b])
    verifyToSet("readById($eqA1.id.toCode).equipToPoints", [ptA1a, ptA1b])
    verifyToSet("readAll(ext).toPoints",    [,])
    verifyToSet("readById($ptA2a.id.toCode).toPoints",  [ptA2a])
    verifyToSet("readAll(point).toPoints",  [ptAa, ptA1a, ptA1b, ptA2a, ptB1a, ptB1b])
    verifyToSet("readAll(dis).toPoints",  [ptAa, ptA1a, ptA1b, ptA2a, ptB1a, ptB1b])
    verifyToSet("readAll(point and siteB).toPoints",  [ptB1a, ptB1b])
    verifyToSet("readAll(site).toPoints",  [ptAa, ptA1a, ptA1b, ptA2a, ptB1a, ptB1b])
    verifyToSet("readAll(space).toPoints",  [ptA1a, ptA1b, ptA2a, ptB1a, ptB1b])
    verifyToSet("readAll(equip).toPoints",  [ptA1a, ptA1b, ptA2a, ptB1a, ptB1b])
    verifyToSet("readAll(device).toPoints",  [ptA1a, ptA1b, ptB1b])
    verifyToSet("readAll(equip and siteA).toPoints", [ptA1a, ptA1b, ptA2a])
    verifyToSet("readAll(id==$siteA.id.toCode).toPoints", [ptAa, ptA1a, ptA1b, ptA2a])
    verifyToSet("readById($siteB.id.toCode).toPoints", [ptB1a, ptB1b])
    verifyToSet("(@$spAQ.id).toPoints", [ptA2a])
    verifyToSet("[@$spAQ.id, @$siteB.id].toPoints", [ptA2a, ptB1a, ptB1b])
    verifyToSet("[@$ptB1b.id, @$spBR.id].toPoints", [ptB1a, ptB1b])
    verifyToSet("[@$dvA1a.id].toPoints", [ptA1a])
  }

  Void verifyToSet(Str axon, Dict?[] recs)
  {
    Grid grid := eval(axon)
    verifyRecIds(grid, recs.map |rec -> Ref?| { rec.id })
  }

//////////////////////////////////////////////////////////////////////////
// ToOccupied
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  virtual Void testToOccupied()
  {
    addLib("hx.point")

    s := addRec(["dis":"S","site":m])

    fA  := addRec(["dis":"Floor-A", "space":m, "siteRef":s.id])
    fB  := addRec(["dis":"Floor-B", "space":m, "siteRef":s.id])
    rB  := addRec(["dis":"Room-B", "space":m, "siteRef":s.id, "spaceRef":fB.id])

    // verify no match error
    verifytoOccupied(s, null)

    eA := addRec(["dis":"EA", "equip":m, "siteRef":s.id, "spaceRef":fA.id])
      pA   := addRec(["dis":"P-EA", "point":m, "siteRef":s.id, "spaceRef":fA.id, "equipRef":eA.id])
      occA := addRec(["dis":"Occ-A","occupied":m, "point":m, "siteRef":s.id, "equipRef":eA.id])
      eAx := addRec(["dis":"EAx", "equip":m, "siteRef":s.id, "spaceRef":fA.id, "equipRef": eA.id])
        pAx := addRec(["dis":"P-EAx", "point":m, "siteRef":s.id, "spaceRef":fA.id, "equipRef":eAx.id])
        eAxy := addRec(["dis":"EAxy", "equip":m, "siteRef":s.id, "spaceRef":fA.id, "equipRef": eAx.id])
        pAxy := addRec(["dis":"P-EAxy", "point":m, "siteRef":s.id, "spaceRef":fA.id, "equipRef":eAxy.id])
    eB := addRec(["dis":"EB", "equip":m, "siteRef":s.id, "spaceRef":rB.id])
      pB   := addRec(["dis":"P-EB", "point":m, "siteRef":s.id, "equipRef":eB.id, "spaceRef":rB.id])
    eS := addRec(["dis":"ES", "equip":m, "siteRef":s.id])
      occS := addRec(["dis":"Occ-S","occupied":m, "point":m, "siteRef":s.id, "equipRef":eS.id])

    // multiple matches
    verifytoOccupied(s, null)

    // site
    occS = commit(occS, ["sitePoint":m])
    proj.sync
    verifytoOccupied(s, occS)

    // equip-A
    verifytoOccupied(eA, occA)
    verifytoOccupied(pA, occA)
    verifytoOccupied(eAx, occA)
    verifytoOccupied(pAx, occA)
    verifytoOccupied(eAxy, occA)
    verifytoOccupied(pAxy, occA)

    // now add occupied to eAx
    occAx := addRec(["dis":"Occ-Ax","occupied":m, "point":m, "siteRef":s.id, "equipRef":eAx.id])
    verifytoOccupied(eA,   occA)
    verifytoOccupied(pA,   occA)
    verifytoOccupied(eAx,  occAx)
    verifytoOccupied(pAx,  occAx)
    verifytoOccupied(eAxy, occAx)
    verifytoOccupied(pAxy, occAx)

    // now add occupied to eAxy
    occAxy := addRec(["dis":"Occ-Axy","occupied":m, "point":m, "siteRef":s.id, "equipRef":eAxy.id])
    verifytoOccupied(eA,   occA)
    verifytoOccupied(pA,   occA)
    verifytoOccupied(eAx,  occAx)
    verifytoOccupied(pAx,  occAx)
    verifytoOccupied(eAxy, occAxy)
    verifytoOccupied(pAxy, occAxy)

    // spaces (and contained equip, points)
    verifytoOccupied(fA, occS)
    verifytoOccupied(fB, occS)
    verifytoOccupied(rB, occS)
    verifytoOccupied(eB, occS)
    verifytoOccupied(pB, occS)

    // now add occupied for floor A + B
    occFa := addRec(["dis":"Occ-FA","occupied":m, "point":m, "siteRef":s.id, "spaceRef":fA.id])
    occFb := addRec(["dis":"Occ-FB","occupied":m, "point":m, "siteRef":s.id, "spaceRef":fB.id])
    verifytoOccupied(fA, occFa)
    verifytoOccupied(fB, occFb)
    verifytoOccupied(rB, occFb)
    verifytoOccupied(eB, occFb)
    verifytoOccupied(pB, occFb)

    // add occupied for room B
    occRb := addRec(["dis":"Occ-FB","occupied":m, "point":m, "siteRef":s.id, "spaceRef":rB.id])
    verifytoOccupied(fA, occFa)
    verifytoOccupied(fB, occFb)
    verifytoOccupied(rB, occRb)
    verifytoOccupied(eB, occRb)
    verifytoOccupied(pB, occRb)

    // remove occA
    commit(occA, null, Diff.remove)
    verifytoOccupied(eA,   occFa)
    verifytoOccupied(pA,   occFa)
    verifytoOccupied(eAx,  occAx)
    verifytoOccupied(pAx,  occAx)
    verifytoOccupied(eAxy, occAxy)
    verifytoOccupied(pAxy, occAxy)
  }

  private Void verifytoOccupied(Dict r, Dict? expected)
  {
    if (expected != null)
    {
      expected = readById(expected.id)
      // echo("-- $r.dis => " + eval("toOccupied($r.id.toCode)->dis") + " ?= " + expected.dis)
      verifySame(eval("toOccupied($r.id.toCode)->id"), expected.id)
      verifySame(eval("readById($r.id.toCode).toOccupied->id"), expected.id)
    }
    else
    {
      verifyNull(eval("toOccupied($r.id.toCode, false)"))
      verifyErr(EvalErr#) { eval("toOccupied($r.id.toCode)") }
      verifyErr(EvalErr#) { eval("toOccupied($r.id.toCode, true)") }
    }
  }

//////////////////////////////////////////////////////////////////////////
// MatchPointVal
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testMatchPointVal()
  {
    addLib("hx.point")

    verifyMatchPointVal("(true, true)",   true)
    verifyMatchPointVal("(true, false)",  false)
    verifyMatchPointVal("(false, false)", true)
    verifyMatchPointVal("(false, true)",  false)

    verifyMatchPointVal("(0,    false)", true)
    verifyMatchPointVal("(0.0,  false)", true)
    verifyMatchPointVal("(0,    true)",  false)
    verifyMatchPointVal("(0.0,  true)",  false)
    verifyMatchPointVal("(44,   false)", false)
    verifyMatchPointVal("(44.0, false)", false)
    verifyMatchPointVal("(44,   true)",  true)
    verifyMatchPointVal("(44.0, true)",  true)

    verifyMatchPointVal("(-1,    0..10)",   false)
    verifyMatchPointVal("(0,     0..10)",   true)
    verifyMatchPointVal("(4,     0..10)",   true)
    verifyMatchPointVal("(4,     0.0 .. 10.0)", true)
    verifyMatchPointVal("(4.0,   0..10)",   true)
    verifyMatchPointVal("(10,    0..10)",   true)
    verifyMatchPointVal("(11,    0..10)",   false)
    verifyMatchPointVal("(11.0,  0..10)",   false)
    verifyMatchPointVal("(true,  0..10)",   false)
    verifyMatchPointVal("(88,    2009-10)", false)

    verifyMatchPointVal("(30) x => x.isEven", true)
    verifyMatchPointVal("(31) x => x.isEven", false)

    // fuzzy 100%
    verifyMatchPointVal("(29.9,  30..100)",  false)
    verifyMatchPointVal("(30.2,  30..100)",  true)
    verifyMatchPointVal("(100.2, 30..100)",  true)
    verifyMatchPointVal("(101,   30..100)",  false)
  }

  private Void verifyMatchPointVal(Str params, Bool expected)
  {
    verifyEq(eval("matchPointVal$params"), expected)
  }

}

