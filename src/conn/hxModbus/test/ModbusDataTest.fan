//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Oct 2012  Andy Frank  Creation
//

using haystack

**
** ModbusDataTest
**
internal class ModbusDataTest : Test
{

//////////////////////////////////////////////////////////////////////////
// Bool
//////////////////////////////////////////////////////////////////////////

  Void testBits()
  {
    a := ModbusData.fromStr("bit")
    b := ModbusData.fromStr("bit:0")
    c := ModbusData.fromStr("bit:2")
    d := ModbusData.fromStr("bit:15")

    verifyBits(a, 0, [0x0000], false)
    verifyBits(a, 0, [0xfff0], false)
    verifyBits(a, 0, [0x0001], true)
    verifyBits(a, 0, [0xffff], true)

    verifyBits(b, 0, [0x0000], false)
    verifyBits(b, 0, [0xfff0], false)
    verifyBits(b, 0, [0x0001], true)
    verifyBits(b, 0, [0xffff], true)

    verifyBits(c, 2, [0x0000], false)
    verifyBits(c, 2, [0xfff0], false)
    verifyBits(c, 2, [0x0007], true)
    verifyBits(c, 2, [0xffff], true)

    verifyBits(d, 15, [0x0000], false)
    verifyBits(d, 15, [0x7fff], false)
    verifyBits(d, 15, [0x8000], true)
    verifyBits(d, 15, [0xffff], true)

    verifyErr(ParseErr#) { ModbusData.fromStr("bi") }
    verifyErr(ParseErr#) { ModbusData.fromStr("bit/0")  }
    verifyErr(ParseErr#) { ModbusData.fromStr("bit2")   }
    verifyErr(ParseErr#) { ModbusData.fromStr("bit:4:") }
    verifyErr(NullErr#)  { a.fromRegs(Int#.emptyList) }
  }

  private Void verifyBits(ModbusBitData data, Int pos, Int[] regs, Bool val)
  {
    verifyEq(data.kind, Kind.bool)
    verifyEq(data.size, 1)
    verifyEq(data.pos, pos)
    verifyEq(data.fromRegs(regs), val)
  }

//////////////////////////////////////////////////////////////////////////
// Int
//////////////////////////////////////////////////////////////////////////

  Void testInts()
  {
    u1 := ModbusData.fromStr("u1")
    u2 := ModbusData.fromStr("u2")
    u4 := ModbusData.fromStr("u4")

    verifyInt(u1, 1, [0x0000], 0)
    verifyInt(u1, 1, [0x0001], 1)
    verifyInt(u1, 1, [0x0080], 128)
    verifyInt(u1, 1, [0x00ff], 255)
    verifyInt(u1, 1, [0xffff], 255, [0xff])

    verifyInt(u2, 1, [0x0000], 0)
    verifyInt(u2, 1, [0x00ff], 255)
    verifyInt(u2, 1, [0x8000], 32768)
    verifyInt(u2, 1, [0xffff], 65535)

    verifyInt(u4, 2, [0x0000, 0x0000], 0)
    verifyInt(u4, 2, [0x0000, 0x00ff], 255)
    verifyInt(u4, 2, [0x0000, 0x8000], 32768)
    verifyInt(u4, 2, [0x0000, 0xffff], 65535)
    verifyInt(u4, 2, [0xffff, 0xffff], 4294967295)

    s1 := ModbusData.fromStr("s1")
    s2 := ModbusData.fromStr("s2")
    s4 := ModbusData.fromStr("s4")
    s8 := ModbusData.fromStr("s8")

    verifyInt(s1, 1, [0x0000], 0)
    verifyInt(s1, 1, [0x000a], 10)
    verifyInt(s1, 1, [0x007f], 127)
    verifyInt(s1, 1, [0x0080], -128, [0xff80])
    verifyInt(s1, 1, [0x00ff], -1,   [0xffff])
    verifyInt(s1, 1, [0xffff], -1,   [0xffff])

    verifyInt(s2, 1, [0x0000], 0)
    verifyInt(s2, 1, [0x000a], 10)
    verifyInt(s2, 1, [0x007f], 127)
    verifyInt(s2, 1, [0x0080], 128)
    verifyInt(s2, 1, [0x00ff], 255)
    verifyInt(s2, 1, [0x7fff], 32767)
    verifyInt(s2, 1, [0x8000], -32768)
    verifyInt(s2, 1, [0xffff], -1)

    verifyInt(s4, 2, [0x0000, 0x0000], 0)
    verifyInt(s4, 2, [0x0000, 0x000a], 10)
    verifyInt(s4, 2, [0x0000, 0x7fff], 32767)
    verifyInt(s4, 2, [0x0000, 0x8000], 32768)
    verifyInt(s4, 2, [0x7fff, 0xffff], 2147483647)
    verifyInt(s4, 2, [0x8000, 0x0000], -2147483648)
    verifyInt(s4, 2, [0xffff, 0xffff], -1)

    verifyInt(s8, 4, [0x0000, 0x0000, 0x0000, 0x0000], 0)
    verifyInt(s8, 4, [0x0000, 0x0000, 0xffff, 0xff0a], 4294967050)
    verifyInt(s8, 4, [0x7fff, 0xffff, 0xffff, 0xffff], Int.maxVal)
    verifyInt(s8, 4, [0x8000, 0x0000, 0x0000, 0x0000], Int.minVal)
    verifyInt(s8, 4, [0xffff, 0xffff, 0xffff, 0xffff], -1)
  }

  Void testIntWriteRaw()
  {
    u1 := ModbusData.fromStr("u1")
    u2 := ModbusData.fromStr("u2")
    u4 := ModbusData.fromStr("u4")

    // test writing multiple raw registers which may not map to Addr width

    verifyIntWrite(u1, [10], [10])
    verifyIntWrite(u2, [10], [10])
    verifyIntWrite(u4, [10], [10])

    verifyIntWrite(u1, [45,80,128], [45,80,128])
    verifyIntWrite(u2, [45,80,128], [45,80,128])
    verifyIntWrite(u4, [45,80,128], [45,80,128])

    verifyIntWrite(u4, "a0b1c2d3e4f5", [0xa0b1, 0xc2d3, 0xe4f5])
    verifyErr(ArgErr#) { verifyIntWrite(u4, "a0b1c2", [0xa0b1, 0xc2]) }
  }

  Void testIntsLittleEndian()
  {
    // u1
    u1  := ModbusData.fromStr("u1le")
    u1b := ModbusData.fromStr("u1leb")
    u1w := ModbusData.fromStr("u1lew")

    verifyInt(u1, 1, [0x0000], 0)
    verifyInt(u1, 1, [0x0100], 1)
    verifyInt(u1, 1, [0x8000], 128)
    verifyInt(u1, 1, [0xff00], 255)

    verifyInt(u1b, 1, [0x0000], 0)
    verifyInt(u1b, 1, [0x0100], 1)
    verifyInt(u1b, 1, [0x8000], 128)
    verifyInt(u1b, 1, [0xff00], 255)

    verifyInt(u1w, 1, [0x0000], 0)
    verifyInt(u1w, 1, [0x0001], 1)
    verifyInt(u1w, 1, [0x0080], 128)
    verifyInt(u1w, 1, [0x00ff], 255)

    // u2
    u2  := ModbusData.fromStr("u2le")
    u2b := ModbusData.fromStr("u2leb")
    u2w := ModbusData.fromStr("u2lew")

    verifyInt(u2, 1, [0x0000], 0)
    verifyInt(u2, 1, [0xff00], 255)
    verifyInt(u2, 1, [0x0080], 32768)
    verifyInt(u2, 1, [0xffff], 65535)

    verifyInt(u2b, 1, [0x0000], 0)
    verifyInt(u2b, 1, [0xff00], 255)
    verifyInt(u2b, 1, [0x0080], 32768)
    verifyInt(u2b, 1, [0xffff], 65535)

    verifyInt(u2w, 1, [0x0000], 0)
    verifyInt(u2w, 1, [0x00ff], 255)
    verifyInt(u2w, 1, [0x8000], 32768)
    verifyInt(u2w, 1, [0xffff], 65535)

    // u4
    u4  := ModbusData.fromStr("u4le")
    u4b := ModbusData.fromStr("u4leb")
    u4w := ModbusData.fromStr("u4lew")

    verifyInt(u4, 2, [0x0000, 0x0000], 0)
    verifyInt(u4, 2, [0xff00, 0x0000], 255)
    verifyInt(u4, 2, [0x0080, 0x0000], 32768)
    verifyInt(u4, 2, [0xffff, 0x0000], 65535)
    verifyInt(u4, 2, [0xffff, 0xffff], 4294967295)

    verifyInt(u4b, 2, [0x0000, 0x0000], 0)
    verifyInt(u4b, 2, [0x0000, 0xff00], 255)
    verifyInt(u4b, 2, [0x0000, 0x0080], 32768)
    verifyInt(u4b, 2, [0x0000, 0xffff], 65535)
    verifyInt(u4b, 2, [0xffff, 0xffff], 4294967295)

    verifyInt(u4w, 2, [0x0000, 0x0000], 0)
    verifyInt(u4w, 2, [0x00ff, 0x0000], 255)
    verifyInt(u4w, 2, [0x8000, 0x0000], 32768)
    verifyInt(u4w, 2, [0xffff, 0x0000], 65535)
    verifyInt(u4w, 2, [0xffff, 0xffff], 4294967295)
  }

  private Void verifyInt(ModbusIntData data, Int size, Int[] regs, Int val, Int[] check := regs)
  {
    num := Number.makeInt(val)
    verifyEq(data.kind, Kind.number)
    verifyEq(data.size, size)
    verifyEq(data.fromRegs(regs), num)
    verifyEq(data.toRegs(num), check)
  }

  private Void verifyIntWrite(ModbusIntData data, Obj raw, Int[] check)
  {
    Obj? val
    if (raw is Int) val = Number.makeInt(val)
    if (raw is Int[])
    {
      nums := Number[,]
      ((Int[])raw).each |i| { nums.add(Number.makeInt(i)) }
      val = nums
    }
    if (raw is Str) val = raw

    verifyEq(data.kind, Kind.number)
    verifyEq(data.toRegs(val), check)
  }

//////////////////////////////////////////////////////////////////////////
// Float
//////////////////////////////////////////////////////////////////////////

  Void testFloats()
  {
    f4 := ModbusData.fromStr("f4")
    f8 := ModbusData.fromStr("f8")

    verifyFloat(f4, 2, [0x0000, 0x0000], 0f)
    verifyFloat(f4, 2, [0x3fc0, 0x0000], 1.5f)
    verifyFloat(f4, 2, [0xbfc0, 0x0000], -1.5f)
    verifyFloat(f4, 2, [0x4413, 0x4000], 589f)

    verifyFloat(f8, 4, [0x0000, 0x0000, 0x0000, 0x0000], 0f)
    verifyFloat(f8, 4, [0x4009, 0x0000, 0x0000, 0x0000], 3.125f)
    verifyFloat(f8, 4, [0xc009, 0x0000, 0x0000, 0x0000], -3.125f)
    verifyFloat(f8, 4, [0x7ff0, 0x0000, 0x0000, 0x0000], Float.posInf)
    verifyFloat(f8, 4, [0xfff0, 0x0000, 0x0000, 0x0000], Float.negInf)
  }

  Void testFloatsLittleEndian()
  {
    f4  := ModbusData.fromStr("f4le")
    f4b := ModbusData.fromStr("f4leb")
    f4w := ModbusData.fromStr("f4lew")

    verifyFloat(f4, 2, [0x0000, 0x0000], 0f)
    verifyFloat(f4, 2, [0x0000, 0xc03f], 1.5f)
    verifyFloat(f4, 2, [0x0000, 0xc0bf], -1.5f)
    verifyFloat(f4, 2, [0x0040, 0x1344], 589f)

    verifyFloat(f4w, 2, [0x0000, 0x0000], 0f)
    verifyFloat(f4w, 2, [0x0000, 0x3fc0], 1.5f)
    verifyFloat(f4w, 2, [0x0000, 0xbfc0], -1.5f)
    verifyFloat(f4w, 2, [0x4000, 0x4413], 589f)

    verifyFloat(f4b, 2, [0x0000, 0x0000], 0f)
    verifyFloat(f4b, 2, [0xc03f, 0x0000], 1.5f)
    verifyFloat(f4b, 2, [0xc0bf, 0x0000], -1.5f)
    verifyFloat(f4b, 2, [0x1344, 0x0040], 589f)
  }

  private Void verifyFloat(ModbusFloatData data, Int size, Int[] regs, Float val)
  {
    verifyEq(data.kind, Kind.number)
    verifyEq(data.size, size)
    verifyEq(data.fromRegs(regs), Number(val))
  }
}