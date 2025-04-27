//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 2025  Brian Frank  Creation
//

using util
using xeto
using haystack
using haystack::Dict
using haystack::Ref

**
** TemplateTest
**
@Js
class TemplateTest : AbstractXetoTest
{

  Void testBasics()
  {
    ns := createNamespace(["sys", "ph", "ph.attrs", "ph.points", "hx.test.xeto"])

    specA := ns.spec("hx.test.xeto::TemplateA")
    zat   := ns.spec("ph.points::ZoneAirTempSensor")
    zah   := ns.spec("ph.points::ZoneAirHumiditySensor")

    // vanilla instantiate
    opts  := Etc.makeDict(["haystack":m, "graph":m])
    Dict[] recs := ns.instantiate(specA, opts)
    verifyEq(recs.size, 3)
    eqId := recs[0].id
    verifyTemplate(recs[0], [
      "navName":"TemplateA",
      "disMacro":"\$siteRef \$navName",
      "spec":specA._id],
      "ahu,equip")
    verifyTemplate(recs[1], [
      "navName":"ZoneAirTempSensor",
      "disMacro":"\$equipRef \$navName",
      "equipRef":eqId,
      "unit":"°F", "kind":"Number", "spec":zat._id],
      "zone,air,temp,sensor,point")
    verifyTemplate(recs[2], [
      "navName":"ZoneAirHumiditySensor",
      "disMacro":"\$equipRef \$navName",
      "equipRef":eqId,
      "unit":"%RH", "kind":"Number", "spec":zah._id],
      "zone,air,humidity,sensor,point")
  }

  Void verifyTemplate(Dict rec, Str:Obj expect, Str markers)
  {
echo
echo("---> $rec.dis")
Etc.dictDump(rec)
    expect.set("id", rec.id)
    markers.split(',').each |n| { expect.set(n, Marker.val) }

    verifyDictEq(rec, expect)
  }

}

