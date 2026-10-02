//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Oct 2013  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using hx

**
** ModbusRegMapTest
**
class ModbusRegMapTest : HxTest
{
  const static ModbusAddrType coil       := ModbusAddrType.coil
  const static ModbusAddrType disInput   := ModbusAddrType.discreteInput
  const static ModbusAddrType inputReg   := ModbusAddrType.inputReg
  const static ModbusAddrType holdingReg := ModbusAddrType.holdingReg

  const static ModbusData bit := ModbusData.fromStr("bit")
  const static ModbusData u2  := ModbusData.fromStr("u2")
  const static ModbusData s4  := ModbusData.fromStr("s4")

  Void test()
  {
    csv :=
      Str<|name,addr,data,rw,unit
           a,40001,u2,rw,
           b,39876,s4,r,kW
           c,10234,bit,r,
           d,00080,bit,rw,|>

    f := tempDir + `modbus.csv`
    f.out.print(csv).flush.close

    // file cache
    mapOrig := ModbusRegMap.fromFile(f)
    verifySame(ModbusRegMap.fromFile(f), mapOrig)
    Actor.sleep(1sec)
    f.out.print(csv).flush.close
    map := ModbusRegMap.fromFile(f)
    verifyNotSame(map, mapOrig)

    // registers
    verifyReg(map.regs[0], "a", null, "40001", holdingReg, 1,     u2, null)
    verifyReg(map.regs[1], "b", null, "39876", inputReg,   9876,  s4, Unit("kW"))
    verifyReg(map.regs[2], "c", null, "10234", disInput,   234,  bit, null)
    verifyReg(map.regs[3], "d", null, "00080", coil,       80,   bit, null)

    // name lookup
    verifySame(map.reg("b"), map.regs[1])
    verifyEq(map.reg("bad", false), null)
    verifyErr(UnknownNameErr#) { map.reg("bad") }
    verifyErr(UnknownNameErr#) { map.reg("bad", true) }
  }

  Void testAddr()
  {
    // types
    verifyEq(ModbusAddrType.coil.isBool, true)
    verifyEq(ModbusAddrType.coil.isNum,  false)
    verifyEq(ModbusAddrType.discreteInput.isBool, true)
    verifyEq(ModbusAddrType.discreteInput.isNum,  false)
    verifyEq(ModbusAddrType.inputReg.isBool, false)
    verifyEq(ModbusAddrType.inputReg.isNum,  true)
    verifyEq(ModbusAddrType.holdingReg.isBool, false)
    verifyEq(ModbusAddrType.holdingReg.isNum,  true)

    // qnum
    verifyEq(ModbusAddr("00005").qnum,  5)
    verifyEq(ModbusAddr("10020").qnum,  10020)
    verifyEq(ModbusAddr("30500").qnum,  30500)
    verifyEq(ModbusAddr("40100").qnum,  40100)
    verifyEq(ModbusAddr("499999").qnum, 49_9999)
  }

  Void testTags()
  {
    aTags := Etc.emptyTags
    bTags := Etc.makeDict(["foo"])
    cTags := Etc.makeDict(["foo","bar","rar"])
    dTags := Etc.emptyTags

    csv :=
      Str<|name,addr,data,rw,tags
           a,40001,u2,rw,
           b,39876,s4,r,foo
           c,10234,bit,r,foo bar rar
           d,00080,bit,rw,|>

    f := tempDir + `modbus2.csv`
    f.out.print(csv).flush.close
    map := ModbusRegMap.fromFile(f)

    verifyReg(map.regs[0], "a", null, "40001", holdingReg, 1,     u2, null, aTags)
    verifyReg(map.regs[1], "b", null, "39876", inputReg,   9876,  s4, null, bTags)
    verifyReg(map.regs[2], "c", null, "10234", disInput,   234,  bit, null, cTags)
    verifyReg(map.regs[3], "d", null, "00080", coil,       80,   bit, null, dTags)
  }

  Void verifyReg(ModbusReg r, Str name, Str? dis, Str addrStr, ModbusAddrType addrType, Int addrNum, ModbusData data, Unit? unit, Obj? tags := null)
  {
    // echo("--> $name $r.addr $r.data")
    verifyEq(r.name, name)
    verifyEq(r.dis, dis ?: name)
    verifyEq(r.addr.toStr, addrStr)
    verifyEq(r.addr.type, addrType)
    verifyEq(r.addr.num, addrNum)
    verifyEq(r.data, data)
    verifyEq(r.unit, unit)
    verifyDictEq(r.tags, tags ?: Etc.emptyTags)
  }

  Void testScale()
  {
    a := ModbusScale("+ 1.5")
    b := ModbusScale("- 100")
    c := ModbusScale("* 15")
    d := ModbusScale("* -6")
    e := ModbusScale("/18.42")
    f := ModbusScale("/-5")

    verifyScale(a, 5.2f,  5.2f + 1.5f)
    verifyScale(b, 275,   275 - 100)
    verifyScale(c, 10,    10 * 15)
    verifyScale(d, 24,    -144)
    verifyScale(e, 92.1f, 92.1f / 18.42f)
    verifyScale(f, 25f,   -5)

    verifyScale(ModbusScale("+ 100 / 10"), 20, (20 + 100) / 10)
    verifyScale(ModbusScale("+ -10 * 2"), 15f, (15f -10f) * 2f)

    // exponents; a sign following e/E is part of the number
    verifyScale(ModbusScale("*1e3"),       5f,   5000f)
    verifyScale(ModbusScale("/1E+2"),      250f, 2.5f)
    verifyScale(ModbusScale("*5e-1"),      10f,  5f)
    verifyScale(ModbusScale("- 2.5E-1"),   10f,  9.75f)
    verifyScale(ModbusScale("*5e-1 -1"),   10f,  4f)
    verifyScale(ModbusScale("*5e-1+1"),    10f,  6f)
    verifyScale(ModbusScale("* -5e-1"),    10f,  -5f)
    verifyEq(ModbusScale("*1e-3").factors.first, Number(0.001f))
    verifyEq(ModbusScale("*1e-", false), null)

    // verifyEq(ModbusScale("+foo").name,   "foo")
    // verifyEq(ModbusScale("-  bar").name, "bar")
    // verifyEq(ModbusScale("* ai0").name,  "ai0")
    // verifyEq(ModbusScale("/ai6").name,   "ai6")
  }

  Void testBadScale()
  {
    // an empty scale cell is simply no scale
    f := tempDir + `scale-ok.csv`
    f.out.print(
      Str<|name,addr,data,rw,scale
           a,40001,u2,r,
           b,40002,u2,r,*0.1|>).flush.close
    map := ModbusRegMap.fromFile(f)
    verifyNull(map.reg("a").scale)
    verifyEq(map.reg("b").scale.compute(Number.makeInt(20)), Number(2f))

    // a malformed one fails the row rather than reading unscaled
    f2 := tempDir + `scale-bad.csv`
    f2.out.print(
      Str<|name,addr,data,rw,scale
           a,40001,u2,r,
           b,40002,u2,r,0.1|>).flush.close
    verifyErrMsg(IOErr#, "Invalid register row [line 3]") |->| { ModbusRegMap.fromFile(f2) }
  }

  Void testBadUnit()
  {
    // an empty unit cell is simply no unit
    f := tempDir + `unit-ok.csv`
    f.out.print(
      Str<|name,addr,data,rw,unit
           a,40001,u2,r,
           b,40002,u2,r,kW|>).flush.close
    map := ModbusRegMap.fromFile(f)
    verifyNull(map.reg("a").unit)
    verifyEq(map.reg("b").unit, Unit("kW"))

    // an unknown one fails the row rather than reading unitless
    f2 := tempDir + `unit-bad.csv`
    f2.out.print(
      Str<|name,addr,data,rw,unit
           a,40001,u2,r,
           b,40002,u2,r,degF|>).flush.close
    verifyErrMsg(IOErr#, "Invalid register row [line 3]") |->| { ModbusRegMap.fromFile(f2) }
  }

  Void testLearn()
  {
    csv :=
      Str<|name,addr,data,rw,unit,tags
           hold2,40050,u2,rw,kW,
           hold1,40010,u2,r,,foo
           input,30020,s4,r,,
           coil,00080,bit,rw,,
           discrete,10234,bit,r,,|>

    f := tempDir + `learn.csv`
    f.out.print(csv).flush.close
    map := ModbusRegMap.fromFile(f)

    // root is a folder per register type in use, in Modicon order
    g := ModbusExt.learnRegMap(map, null)
    folders := Str[,]
    keys    := Str[,]
    g.each |r| { folders.add(r->dis); keys.add(r->learn) }
    verifyEq(folders, ["Coils", "Discrete Inputs", "Input Registers", "Holding Registers"])
    verifyEq(keys,    ["coil", "discreteInput", "inputReg", "holdingReg"])

    kids := Str:Dict[][:]
    keys.each |k, i|
    {
      rows := Dict[,]
      ModbusExt.learnRegMap(map, ModbusAddrType.fromStr(k)).each |r| { rows.add(r) }
      kids[folders[i]] = rows
    }

    // registers sort by number within their folder
    hold := kids["Holding Registers"]
    verifyEq(hold.map |r->Str| { r->dis }, ["hold1", "hold2"])

    // a readable register names itself for cur only, and keeps its csv tags
    verifyEq(hold[0]["modbusCur"],   "hold1")
    verifyEq(hold[0]["modbusWrite"], null)
    verifyEq(hold[0]["kind"],        "Number")
    verifyEq(hold[0]["point"],       Marker.val)
    verifyEq(hold[0]["foo"],         Marker.val)

    // rw names itself for both, and carries its unit
    verifyEq(hold[1]["modbusCur"],   "hold2")
    verifyEq(hold[1]["modbusWrite"], "hold2")
    verifyEq(hold[1]["unit"],        "kW")

    verifyEq(kids["Coils"].first["kind"],          "Bool")
    verifyEq(kids["Discrete Inputs"].first["dis"], "discrete")
    verifyEq(kids["Input Registers"].first["modbusCur"], "input")
  }

  Void verifyScale(ModbusScale scale, Num in, Num out)
  {
    nin  := in  is Int ? Number.makeInt(in)  : Number((Float)in)
    nout := out is Int ? Number.makeInt(out) : Number((Float)out)
    verifyEq(scale.compute(nin), nout)
    verifyEq(scale.inverse(nout), nin)
  }
}

