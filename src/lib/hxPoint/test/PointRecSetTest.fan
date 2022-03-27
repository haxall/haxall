//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Mar 2022  Brian Frank  Creation
//

using concurrent
using haystack
using obs
using folio
using hx

**
** PointRecSetTest
**
class PointRecSetTest : HxTest
{

  @HxRuntimeTest
  Void testSets()
  {
    // ext
    addLib("point")

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
// MatchPointVal
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testMatchPointVal()
  {
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