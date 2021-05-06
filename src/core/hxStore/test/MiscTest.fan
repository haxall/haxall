//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2016  Brian Frank  Creation
//

**
** MiscTest
**
class MiscTest : Test
{
  Tests java() { Tests(JavaTestBridge(this)) }

  Void testIO() { java.testIO }

  Void testFreeMap() { java.testFreeMap }

  Void testBlobMap() { java.testBlobMap }

  Void testHandleToStr()
  {
    verifyHandleToStr(0xabcd_ef98_0000_0000, "abcdef98.0")
    verifyHandleToStr(0xabcd_ef98_0000_0017, "abcdef98.17")
    verifyHandleToStr(0x1234_5678_abcd_0000, "12345678.abcd0000")
  }

  Void verifyHandleToStr(Int h, Str s)
  {
    verifyEq(Blob.handleToStr(h), s)
    verifyEq(Blob.handleFromStr(s), h)
  }

  Void testBlobMeta()
  {
    m := BlobMeta(Buf())
    verifyEq(m.size, 0)
    verifySame(m.typeof, BlobMeta#)
    verifySame(m, BlobMeta(Buf()))

    buf := Buf()
    buf.writeI2(0xabcd)
       .write('h')
       .writeI4(0x0a0b0c0d)
       .writeI8(0x1122334455667788)
       .writeI8(0xFFEEDDCCBBAA9988)
       .writeI4(0xF7D7C7B7)
       .write('!')
    m = BlobMeta(buf)
    verifyEq(m.size, 28)
    verifySame(m.typeof, BlobMeta#)
    verifyEq(m.readU2(0).toHex, 0xabcd.toHex)
    verifyEq(m[2], 'h')
    verifyEq(m.readU4(3), 0x0a0b0c0d)
    verifyEq(m.readS8(7).toHex, "1122334455667788")
    verifyEq(m.readS8(15).toHex.upper, "FFEEDDCCBBAA9988")
    verifyEq(m.readU4(23).toHex.upper, "F7D7C7B7")
    verifyEq(m.get(27), '!')

    // signed ints
    buf = Buf()
    buf.writeI8(-188897262065272)
       .writeI4(-1546369200)
       .writeI2(-32001)
       .write(-100)
       .write(0xfc)
    m = BlobMeta(buf)
    verifyEq(m.size, 16)
    verifyEq(m.readS8(0), -188897262065272)
    verifyEq(m.readS4(8), -1546369200)
    verifyEq(m.readS2(12), -32001)
    verifyEq(m.readS1(14), -100)
    verifyEq(m.readS1(14), -100)
    verifyEq(m.readU1(15), 0xfc)

    // const buf with larger capacity
    buf = Buf(100).print("123")
    verifyEq(buf.size, 3)
    verifyEq(buf.capacity, 100)
    m = BlobMeta(buf.toImmutable)
    buf.clear.print("abcd")
    verifyEq(m.size, 3)
    verifyEq(m[0], '1')
    verifyEq(m[1], '2')
    verifyEq(m[2], '3')

    // const buf with exact capacity
    buf = Buf(3).print("123")
    verifyEq(buf.size, 3)
    verifyEq(buf.capacity, 3)
    m = BlobMeta(buf.toImmutable)
    buf.clear.print("abc")
    verifyEq(m.size, 3)
    verifyEq(m[0], '1')
    verifyEq(m[1], '2')
    verifyEq(m[2], '3')
  }
}

**************************************************************************
** Tests
**************************************************************************

native const class Tests
{
  new make(JavaTestBridge bridge)

  Void testIO()
  Void testFreeMap()
  Void testBlobMap()
}