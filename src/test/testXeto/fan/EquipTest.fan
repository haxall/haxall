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

**
** EquipTest
**
@Js
class EquipTest : AbstractXetoTest
{

  ** Untyped constraint slots bind to globals contributed by mixins
  ** in the dependency chain: the addr slots infer type and implicit
  ** maybe from ph.protocols +PhEntity.  Runs local and remote so the
  ** base refs into mixin members are verified across the wire.
  Void testMixinInference()
  {
    verifyLocalAndRemote(["sys", "ph", "ph.attrs", "ph.points", "ph.points.sugar", "hx.test.xeto"]) |ns| { doTestMixinInference(ns) }
  }

  Void doTestMixinInference(Namespace ns)
  {
    zt := ns.spec("hx.test.xeto::EquipNamed").slot("points").slot("zoneTemp")

    ma := zt.slot("modbusCurAddr")
    verifyEq(ma.type.qname, "ph.protocols::ModbusAddr")
    verifyEq(ma.isMaybe, true)
    verifyEq(ma.base.qname, "ph.protocols::PhEntity.modbusCurAddr")
    verifyEq(ma.base.isGlobal, true)
    verifyEq(ma.slot("addr").meta["val"]?.toStr, "1001")
    verifyEq(ma.slot("access").meta["val"]?.toStr, "rw")

    ba := zt.slot("bacnetCurAddr")
    verifyEq(ba.type.qname, "ph.protocols::BacnetAddr")
    verifyEq(ba.isMaybe, true)
    verifyEq(ba.base.qname, "ph.protocols::PhEntity.bacnetCurAddr")
    verifyEq(ba.base.isGlobal, true)
    verifyEq(ba.slot("addr").meta["val"]?.toStr, "AI1")

    // plain globals declared within the type chain drive inference the
    // same way: an authored dis in a template binds the implicitly
    // maybe PhEntity.dis global, so the slot is not required
    zc := ns.spec("hx.test.xeto::EquipNamed").slot("points").slot("zoneCo2")
    dis := zc.slot("dis")
    verifyEq(dis.type.qname, "sys::Str")
    verifyEq(dis.base.isGlobal, true)
    verifyEq(dis.isMaybe, true)
    verifyEq(ns.spec("ph::PhEntity").globals.get("dis").isMaybe, true)

    // same-lib inherited members bind the same way
    a0 := ns.spec("hx.test.xeto::EquipA").slot("points").slot("_0")
    verifyEq(a0.slot("modbusCurAddr").type.qname, "ph.protocols::ModbusAddr")
    verifyEq(a0.slot("modbusCurAddr").base.isGlobal, true)
  }

  Void testBasics()
  {
    ns := createNamespace(["sys", "ph", "ph.attrs", "ph.points", "ph.points.sugar", "hx.test.xeto"])

    specA   := ns.spec("hx.test.xeto::EquipA")
    zat     := ns.spec("ph.points::ZoneAirTempSensor")
    zah     := ns.spec("ph.points::ZoneAirHumiditySensor")
    qn0     := specA.slot("points").slot("_0").qname
    qn1     := specA.slot("points").slot("_1").qname

    // vanilla instantiate
    opts  := Etc.makeDict(["haystack":m, "graph":m])
    Dict[] recs := ns.instantiate(specA, opts)
    verifyEq(recs.size, 3)
    eqId := recs[0].id
    verifyTemplate(recs[0], [
      "navName":"EquipA",
      "disMacro":"\$siteRef \$navName",
      "spec":specA.id],
      "ahu,equip")
    verifyTemplate(recs[1], [
      "navName":"ZoneAirTempSensor",
      "disMacro":"\$equipRef \$navName",
      "equipRef":eqId,
      "unit":"°F", "kind":"Number", "spec":zat.id],
      "zone,air,temp,sensor,point")
    verifyTemplate(recs[2], [
      "navName":"ZoneAirHumiditySensor",
      "disMacro":"\$equipRef \$navName",
      "equipRef":eqId,
      "unit":"%RH", "kind":"Number", "spec":zah.id],
      "zone,air,humidity,sensor,point")

    // instantiate with site + graphInclude
    s := Etc.makeDict(["id":Ref("site-1"), "dis":"Site-1", "site":m])
    include := [qn1:qn1]
    opts = Etc.makeDict(["haystack":m, "graph":m, "graphInclude":include, "parent":s])
    recs = ns.instantiate(specA, opts)
    eqId = recs[0].id
    verifyEq(recs.size, 2)
    verifyTemplate(recs[0], [
      "navName":"EquipA",
      "disMacro":"\$siteRef \$navName",
      "siteRef":s.id,
      "spec":specA.id],
      "ahu,equip")
    verifyTemplate(recs[1], [
      "navName":"ZoneAirHumiditySensor",
      "disMacro":"\$equipRef \$navName",
      "siteRef":s.id,
      "equipRef":eqId,
      "unit":"%RH", "kind":"Number", "spec":zah.id],
      "zone,air,humidity,sensor,point")


    // instantiate with space + graphInclude
    sp := Etc.makeDict(["id":Ref("space"), "dis":"Space-1", "space":m, "siteRef":s.id])
    opts = Etc.makeDict(["haystack":m, "graph":m, "graphInclude":include, "parent":sp])
    recs = ns.instantiate(specA, opts)
    eqId = recs[0].id
    verifyEq(recs.size, 2)
    verifyTemplate(recs[0], [
      "navName":"EquipA",
      "disMacro":"\$siteRef \$navName",
      "siteRef":s.id,
      "spaceRef":sp.id,
      "spec":specA.id],
      "ahu,equip")
    verifyTemplate(recs[1], [
      "navName":"ZoneAirHumiditySensor",
      "disMacro":"\$equipRef \$navName",
      "siteRef":s.id,
      "spaceRef":sp.id,
      "equipRef":eqId,
      "unit":"%RH", "kind":"Number", "spec":zah.id],
      "zone,air,humidity,sensor,point")

    // instantiate with equip that has siteRef, spaceRef, and systemRef
    sys := Etc.makeDict(["id":Ref("sys"), "dis":"System", "system":m, "siteRef":s.id])
    peq := Etc.makeDict(["id":Ref("peq"), "dis":"P-Eq", "equip":m, "siteRef":s.id, "systemRef":[sys.id], "spaceRef":sp.id])
    opts = Etc.makeDict(["haystack":m, "graph":m, "graphInclude":include, "parent":peq])
    recs = ns.instantiate(specA, opts)
    eqId = recs[0].id
    verifyEq(recs.size, 2)
    verifyTemplate(recs[0], [
      "navName":"EquipA",
      "disMacro":"\$siteRef \$navName",
      "siteRef":s.id,
      "spaceRef":sp.id,
      "systemRef":[sys.id],
      "equipRef":peq.id,
      "spec":specA.id],
      "ahu,equip")
    verifyTemplate(recs[1], [
      "navName":"ZoneAirHumiditySensor",
      "disMacro":"\$equipRef \$navName",
      "siteRef":s.id,
      "spaceRef":sp.id,
      "systemRef":[sys.id],
      "equipRef":eqId,
      "unit":"%RH", "kind":"Number",  "spec":zah.id],
      "zone,air,humidity,sensor,point")

    // instantiate with connector
    conn := Etc.makeDict(["id":Ref("bc"), "addrSpec":Ref("ph.protocols::BacnetAddr")])
    opts = Etc.makeDict(["haystack":m, "graph":m, "conn":conn])
    recs = ns.instantiate(specA, opts)
    eqId = recs[0].id
    verifyEq(recs.size, 3)
    verifyTemplate(recs[0], [
      "navName":"EquipA",
      "disMacro":"\$siteRef \$navName",
      "spec":specA.id],
      "ahu,equip")
    verifyTemplate(recs[1], [
      "navName":"ZoneAirTempSensor",
      "disMacro":"\$equipRef \$navName",
      "equipRef":eqId,
      "bacnetPoint":m,
      "bacnetConnRef":conn.id,
      "bacnetCur":"AI3",
      "unit":"°F", "kind":"Number", "spec":zat.id],
      "zone,air,temp,sensor,point")
    verifyTemplate(recs[2], [
      "navName":"ZoneAirHumiditySensor",
      "disMacro":"\$equipRef \$navName",
      "equipRef":eqId,
      "bacnetPoint":m,
      "bacnetConnRef":conn.id,
      "bacnetCur":"AI4",
      "unit":"%RH", "kind":"Number", "spec":zah.id],
      "zone,air,humidity,sensor,point")
  }

  Void verifyTemplate(Dict rec, Str:Obj expect, Str markers)
  {
    // echo; echo("---> $rec.dis"); Etc.dictDump(rec)

    expect.set("id", rec.id)
    markers.split(',').each |n| { expect.set(n, Marker.val) }

    verifyDictEq(rec, expect)
  }

}

