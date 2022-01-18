//
// Copyright (c) 2017, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Feb 2017  Andy Frank  Creation
//

using haystack

**
** ModbusBlockTest
**
internal class ModbusBlockTest : Test
{

//////////////////////////////////////////////////////////////////////////
// testBasics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    a := reg("a", "40001", "u2")
    b := reg("b", "40002", "u2")
    c := reg("c", "40003", "u2")
    d := reg("d", "40004", "u2")
    e := reg("e", "40005", "u2")
    f := reg("f", "40006", "u2")

    blocks := ModbusBlock.optimize([a,b,c,d,e])
    verifyEq(blocks.size, 1)
    verifyEq(blocks[0].regs, [a,b,c,d,e])

    blocks = ModbusBlock.optimize([a,b,c,e,f])
    verifyEq(blocks.size, 2)
    verifyEq(blocks[0].regs, [a,b,c])
    verifyEq(blocks[1].regs, [e,f])

    // gaps
    blocks = ModbusBlock.optimize([a,b,c,e,f], 1)
    verifyEq(blocks.size, 1)
    verifyEq(blocks[0].regs, [a,b,c,e,f])

    // max
    blocks = ModbusBlock.optimize([a,b,c,d], 0, 1)
    verifyEq(blocks.size, 4)
    verifyEq(blocks[0].regs, [a])
    verifyEq(blocks[1].regs, [b])
    verifyEq(blocks[2].regs, [c])
    verifyEq(blocks[3].regs, [d])

    // empty
    blocks = ModbusBlock.optimize([,])
    verifyEq(blocks.size, 0)
  }

//////////////////////////////////////////////////////////////////////////
// testRegTypes
//////////////////////////////////////////////////////////////////////////

  Void testRegTypes()
  {
    // normal regs
    c1 := reg("c1", "00001", "u2")
    c2 := reg("c2", "09999", "u2")
    d1 := reg("d1", "10001", "u2")
    d2 := reg("d2", "19999", "u2")
    i1 := reg("i1", "30001", "u2")
    i2 := reg("i2", "39999", "u2")
    h1 := reg("h1", "40001", "u2")
    h2 := reg("h2", "49999", "u2")

    blocks := ModbusBlock.optimize([h2,h1,c1,c2,i1,i2,d1,d2], 10_000, 10_000)
    verifyEq(blocks.size, 4)
    verifyEq(blocks[0].regs, [c1,c2])
    verifyEq(blocks[1].regs, [d1,d2])
    verifyEq(blocks[2].regs, [i1,i2])
    verifyEq(blocks[3].regs, [h1,h2])

    // extended regs
    // c1 := reg("c1", "000001", "u2")
    // c2 := reg("c2", "099999", "u2")
    // d1 := reg("d1", "100001", "u2")
    // d2 := reg("d2", "199999", "u2")
    // i1 := reg("i1", "300001", "u2")
    // i2 := reg("i2", "399999", "u2")
    // h1 := reg("h1", "400001", "u2")
    // h2 := reg("h2", "499999", "u2")
    //
    // blocks := ModbusBlock.optimize([h2,h1,c1,c2,i1,i2,d1,d2], 100_000, 100_000)
    // verifyEq(blocks.size, 4)
    // verifyEq(blocks[0].regs, [c1,c2])
    // verifyEq(blocks[1].regs, [d1,d2])
    // verifyEq(blocks[2].regs, [i1,i2])
    // verifyEq(blocks[3].regs, [h1,h2])
  }

//////////////////////////////////////////////////////////////////////////
// testDataTypes
//////////////////////////////////////////////////////////////////////////

  Void testDataTypes()
  {
    a := reg("a", "40001", "u2")
    b := reg("b", "40002", "u1")
    c := reg("c", "40003", "u4")
    d := reg("d", "40005", "u2")
    e := reg("e", "40006", "bit:1")
    f := reg("f", "40006", "bit:2")
    g := reg("g", "40007", "f8")
    h := reg("h", "40010", "s4")

    blocks := ModbusBlock.optimize([a,b,c,d,e,f,g,h])
    verifyEq(blocks.size, 1)
    verifyEq(blocks[0].start, 1)
    verifyEq(blocks[0].size,  11)

    blocks = ModbusBlock.optimize([c], 0, 1)
    verifyEq(blocks.size, 1)
    verifyEq(blocks[0].start, 3)
    verifyEq(blocks[0].size,  2)

    blocks = ModbusBlock.optimize([a,b,c], 0, 1)
    verifyEq(blocks.size, 3)
    verifyEq(blocks[2].start, 3)
    verifyEq(blocks[2].size,  2)

    blocks = ModbusBlock.optimize([g,h], 0, 1)
    verifyEq(blocks.size, 2)
    verifyEq(blocks[0].start, 7)
    verifyEq(blocks[0].size,  4)
  }

//////////////////////////////////////////////////////////////////////////
// Private
//////////////////////////////////////////////////////////////////////////

  private ModbusReg reg(Str name, Str addr, Str data)
  {
    ModbusReg
    {
      it.name = name
      it.addr = ModbusAddr.fromStr(addr)
      it.data = ModbusData.fromStr(data)
      it.readable = true
      it.writable = true
    }
  }
}