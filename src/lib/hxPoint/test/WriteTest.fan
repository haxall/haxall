//
// Copyright (c) 2012, SkyFoundry LLC
// All Rights Reserved
//
// History:
//   21 Jul 2012  Brian Frank  Creation
//

using haystack
using concurrent
using folio
using hx

**
** WriteTest
**
class WriteTest : HxTest
{

  @HxRuntimeTest
  Void testWrites()
  {
    PointLib lib := rt.libs.add("point")

    pt := addRec(["dis":"P", "point":m, "writable":m, "kind":"Number"])
    ptId := pt.id.toCode

    // initial state
    verifyWrite(lib, pt, null, 17, [:])

    // write def
    eval("pointSetDef($ptId, 170)")
    verifyWrite(lib, pt, n(170), 17, [17:n(170)])

    // level 14
    eval("pointWrite($ptId, 140, 14, \"test-14\")")
    verifyWrite(lib, pt, n(140), 14, [14: n(140), 17:n(170)])

    // manual 8
    eval("pointOverride($ptId, 88)")
    verifyWrite(lib, pt, n(88), 8, [8:n(88), 14: n(140), 17:n(170)])
    eval("pointOverride($ptId, 80)")
    verifyWrite(lib, pt, n(80), 8, [8:n(80), 14: n(140), 17:n(170)])

    // add curTracksWrite
    pt = rt.db.commit(Diff(rt.db.readById(pt.id), ["curTracksWrite":m])).newRec

    // emergency 1
    eval("pointEmergencyOverride($ptId, 10)")
    verifyWrite(lib, pt, n(10), 1, [1:n(10), 8:n(80), 14: n(140), 17:n(170)])

    // auto 1
    eval("pointEmergencyAuto($ptId)")
    verifyWrite(lib, pt, n(80), 8, [8:n(80), 14: n(140), 17:n(170)])

    // auto 8
    eval("pointAuto($ptId)")
    verifyWrite(lib, pt, n(140), 14, [14: n(140), 17:n(170)])

    // auto 14
    eval("pointWrite($ptId, null, 14, \"test-14\")")
    verifyWrite(lib, pt, n(170), 17, [17:n(170)])

    // auto def
    eval("pointSetDef($ptId, null)")
    verifyWrite(lib, pt, null, 17, [:])

  }

  Grid verifyWrite(PointLib lib, Dict pt, Obj? val, Int level, Int:Obj? levels)
  {
    rt.sync
    pt = rt.db.readById(pt.id)
    if (pt.missing("writeLevel"))
    {
      rt.db.sync
      pt = rt.db.readById(pt.id)
    }

    //echo("==> $val @ $level  ?=  " + pt["writeVal"] + " @ " + pt["writeLevel"] + " | " + pt["curVal"] + " @ " + pt["curStatus"])

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
    return g
  }
}

