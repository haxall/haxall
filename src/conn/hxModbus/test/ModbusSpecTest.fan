//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Sep 2026  Matthew Giannini  Creation
//

using xeto
using haystack

**
** ModbusSpecTest verifies mapping a ph.protocols::ModbusAddr spec
** onto a ModbusReg
**
internal class ModbusSpecTest : Test
{
  private const Str lib := "hx.test.xeto::ModbusEquip.points."

  private once Namespace ns() { XetoEnv.cur.resolveNamespace(["hx.test.xeto"]) }

  private ModbusReg reg(Str point, Bool forWrite := false, Str tag := "modbusCurAddr")
  {
    ModbusReg.fromSpec(ns.spec("${lib}${point}").slot(tag), forWrite)
  }

//////////////////////////////////////////////////////////////////////////
// testData
//////////////////////////////////////////////////////////////////////////

  Void testData()
  {
    // bit index selects the bit, unauthored index is bit zero
    verifyEq(reg("regBit").data.toStr,    "bit:2")
    verifyEq(reg("regBitOff").data.toStr, "bit:1")
    verifyEq(reg("regBitDef").data.toStr, "bit:0")
    verifyEq(reg("coil").data.toStr,      "bit:0")

    // byte order maps to the data name suffix, big endian has none
    verifyEq(reg("wordSwap").data.toStr, "u4lew")
    verifyEq(reg("byteSwap").data.toStr, "u4leb")
    verifyEq(reg("inputF4").data.toStr,  "f4le")
    verifyEq(reg("bigEnd").data.toStr,   "u4")
    verifyEq(reg("scaled").data.toStr,   "u2")
  }

//////////////////////////////////////////////////////////////////////////
// testAddr
//////////////////////////////////////////////////////////////////////////

  Void testAddr()
  {
    // the leading digit selects the register type
    verifyEq(reg("coil").addr.type,     ModbusAddrType.coil)
    verifyEq(reg("discrete").addr.type, ModbusAddrType.discreteInput)
    verifyEq(reg("inputF4").addr.type,  ModbusAddrType.inputReg)
    verifyEq(reg("wordSwap").addr.type, ModbusAddrType.holdingReg)

    // six digit addr keeps all five register digits
    verifyEq(reg("wordSwap").addr.num, 11)
    verifyEq(reg("coil").addr.num,     101)
    verifyEq(reg("discrete").addr.num, 103)
    verifyEq(reg("scaled").addr.num,   10)
  }

//////////////////////////////////////////////////////////////////////////
// testScale
//////////////////////////////////////////////////////////////////////////

  Void testScale()
  {
    verifyNull(reg("regBit").scale)

    // ops apply left to right: (raw + 32768) / 10
    scale := reg("scaled").scale
    verifyEq(scale.compute(Number.makeInt(2)), Number(3277f))
  }

//////////////////////////////////////////////////////////////////////////
// testAccess
//////////////////////////////////////////////////////////////////////////

  Void testAccess()
  {
    // read/write comes from which global carried the addr, never from the
    // addr's own access field which defaults to "r"
    cur := reg("split")
    verifyEq(cur.readable, true)
    verifyEq(cur.writable, false)

    write := reg("split", true, "modbusWriteAddr")
    verifyEq(write.readable, false)
    verifyEq(write.writable, true)
    verifyEq(write.addr.num, 42)

    // hx.test.xeto authors access:"rw" here, which must not make it writable
    zone := ModbusReg.fromSpec(ns.spec("hx.test.xeto::EquipNamed.points.zoneTemp").slot("modbusCurAddr"), false)
    verifyEq(zone.writable, false)
  }

//////////////////////////////////////////////////////////////////////////
// testNaming
//////////////////////////////////////////////////////////////////////////

  Void testNaming()
  {
    // the register is named by the qname it was resolved from
    r := reg("wordSwap")
    verifyEq(r.name, "hx.test.xeto::ModbusEquip.points.wordSwap")

    // an unauthored dis is empty rather than null, so it falls back to name
    verifyEq(r.dis, r.name)
    verifyEq(reg("named").dis, "Vendor Tag")

    // a vendor may name the point rather than the addr - iSMA does
    verifyEq(reg("pointNamed").dis, "Vendor Point")
  }

//////////////////////////////////////////////////////////////////////////
// testLearn
//////////////////////////////////////////////////////////////////////////

  Void testLearn()
  {
    // root is one folder per register type in use, in Modicon order. The
    // learn key is a scalar: the nav tree round-trips it through a ref.
    g := ModbusExt.learnSpec(ns, "hx.test.xeto::ModbusEquip", null)
    verifyEq(names(g), ["Coils", "Discrete Inputs", "Input Registers", "Holding Registers"])
    keys := Str[,]
    g.each |r| { keys.add(r->learn) }
    verifyEq(keys, ["coil", "discreteInput", "inputReg", "holdingReg"])

    // expanding a folder returns that type's points, by register number
    verifyEq(names(points("coil")),          ["coil", "coilCmd"])
    verifyEq(names(points("discreteInput")), ["discrete"])
    verifyEq(names(points("inputReg")),      ["inputF4"])
    verifyEq(names(points("holdingReg")),
      ["scaled", "bigEnd", "wordSwap", "byteSwap", "regBit", "regBitOff",
       "regBitDef", "Vendor Tag", "Vendor Point", "split"])

    // a point row carries no learn key, so the tree stops there
    coils := points("coil")
    verifyEq(coils.first["learn"], null)

    // a read only point names its cur addr and nothing else
    c := coils.first
    verifyEq(c["modbusCur"],   "hx.test.xeto::ModbusEquip.points.coil")
    verifyEq(c["modbusWrite"], null)
    verifyEq(c["point"],       Marker.val)
    verifyEq(c["kind"],        "Bool")

    // a writable point names the same point spec for both
    sp := points("holdingReg").last
    verifyEq(sp["dis"],         "split")
    verifyEq(sp["modbusCur"],   "hx.test.xeto::ModbusEquip.points.split")
    verifyEq(sp["modbusWrite"], "hx.test.xeto::ModbusEquip.points.split")
    verifyEq(sp["kind"],        "Number")
    verifyEq(sp["unit"],        "°F")

    // write only point has no cur
    cmd := coils.last
    verifyEq(cmd["modbusCur"],   null)
    verifyEq(cmd["modbusWrite"], "hx.test.xeto::ModbusEquip.points.coilCmd")

    // an unresolved qname distinguishes a disabled lib from a bad spec
    verifyErrMsg(FaultErr#, "Unknown 'modbusDeviceSpec' spec: hx.test.xeto::Nope") |->|
    {
      ModbusExt.learnSpec(ns, "hx.test.xeto::Nope", null)
    }
    verifyErrMsg(FaultErr#, "Lib not enabled in this project for 'modbusDeviceSpec': no.such.lib") |->|
    {
      ModbusExt.learnSpec(ns, "no.such.lib::Thing", null)
    }
  }

  private Dict[] points(Str type)
  {
    g := ModbusExt.learnSpec(ns, "hx.test.xeto::ModbusEquip", ModbusAddrType.fromStr(type))
    rows := Dict[,]
    g.each |r| { rows.add(r) }
    return rows
  }

  private Str[] names(Obj rows)
  {
    acc := Str[,]
    if (rows is Grid) ((Grid)rows).each |r| { acc.add(r->dis) }
    else ((Dict[])rows).each |r| { acc.add(r->dis) }
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// testPointIn
//////////////////////////////////////////////////////////////////////////

  Void testPointIn()
  {
    spec := ns.spec("hx.test.xeto::ModbusEquip")

    // modbusPingAddr names a point of the device spec by slot name
    pt := ModbusDev.pointIn(spec, "regBit")
    verifyEq(pt?.qname, "hx.test.xeto::ModbusEquip.points.regBit")
    verifyEq(ModbusReg.fromSpec(pt.slot("modbusCurAddr"), false).addr.num, 21)

    // unknown names resolve to null rather than throwing
    verifyNull(ModbusDev.pointIn(spec, "nope"))

    // only query slots are searched, so a spec's own slots never match
    verifyNull(ModbusDev.pointIn(spec, "points"))
  }

//////////////////////////////////////////////////////////////////////////
// testPositional
//////////////////////////////////////////////////////////////////////////

  Void testPositional()
  {
    // a named slot path resolves
    ModbusDev.checkNamed("acme.vav::Vav.points.zoneTemp")
    ModbusDev.checkNamed("acme.vav::Vav.points._zone.modbusCurAddr")
    ModbusDev.checkNamed("acme.vav::Vav.points._")

    // an auto-named one is positional and cannot identify a register
    verifyErr(FaultErr#) |->| { ModbusDev.checkNamed("acme.vav::Vav.points._0") }
    verifyErr(FaultErr#) |->| { ModbusDev.checkNamed("acme.vav::Vav.points._12.modbusCurAddr") }
  }

//////////////////////////////////////////////////////////////////////////
// testErrs
//////////////////////////////////////////////////////////////////////////

  Void testErrs()
  {
    // encoding is required
    verifyErr(FaultErr#) |->|
    {
      ModbusReg.fromSpec(ns.spec("hx.test.xeto::EquipNamed.points.zoneCo2").slot("bacnetCurAddr"), false)
    }
  }
}
