//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class DemuxTest : HxCompTest
{
  Void testNumberToBitsDemux()
  {
    TestHxCompContext().asCur |cx|
    {
      NumberToBitsDemux c := createAndExec("NumberToBitsDemux")
      verifyBitsDemux(c, null)
      verifyBitsDemux(c, sn(1))
      verifyBitsDemux(c, sn(0b10101010_10101010))
      verifyBitsDemux(c, sn(0xFF_FF_FF_FF_FF_FF_FF_FF))
    }
  }

  private Void verifyBitsDemux(NumberToBitsDemux c, StatusNumber? in)
  {
    setAndExec(c, "in", in)
    val := in?.num?.toInt
    expected := 0
    64.times |i|
    {
      slot := "bit${i}"
      bit  := c.get(slot) as StatusBool
      if (bit == null) verifyNull(val)
      else expected = expected.or((bit.bool ? 1 : 0).shiftl(i))
    }
    if (val != null) verifyEq(val, expected)

    expected = 0
    8.times |i|
    {
      slot := "byte${i}"
      byte := c.get(slot) as StatusNumber
      if (byte == null) verifyNull(val)
      else expected = expected.or(byte.num.toInt.shiftl(8*i))
    }
    if (val != null) verifyEq(val, expected)
  }

  Void testDigitalInputDemux()
  {
    TestHxCompContext().asCur |cx|
    {
      DigitalInputDemux c := createAndExec("DigitalInputDemux")

      verifyNull(c.out1)
      verifyNull(c.out2)
      verifyNull(c.out3)
      verifyNull(c.out4)

      verifyEq(c.out1Value, 4.8f)
      verifyEq(c.out2Value, 2.4f)
      verifyEq(c.out3Value, 1.2f)
      verifyEq(c.out4Value, 0.6f)
      verifyEq(c.deadband, 0.1f)

      verifyDID(c, 4.8f,                [true,false,false,false])
      verifyDID(c, 4.8f+2.4f,           [true,true,false,false])
      verifyDID(c, 4.8f+1.2f,           [true,false,true,false])
      verifyDID(c, 4.8f+0.6f,           [true,false,false,true])
      verifyDID(c, 4.8f+2.4f+1.2f,      [true,true,true,false])
      verifyDID(c, 4.8f+2.4f+0.6f,      [true,true,false,true])
      verifyDID(c, 4.8f+1.2f+0.6f,      [true,false,true,true])
      verifyDID(c, 4.8f+2.4f+1.2f+0.6f, [true,true,true,true])

      verifyDID(c, 2.4f,           [false,true,false,false])
      verifyDID(c, 2.4f+1.2f,      [false,true,true,false])
      verifyDID(c, 2.4f+0.6f,      [false,true,false,true])
      verifyDID(c, 2.4f+1.2f+0.6f, [false,true,true,true])

      verifyDID(c, 1.2f,      [false,false,true,false])
      verifyDID(c, 1.2f+0.6f, [false,false,true,true])

      verifyDID(c, 0.6f, [false,false,false,true])

      // with some deadband
      verifyDID(c, 4.81f,                   [true, false, false, false])
      verifyDID(c, 4.81f+2.41f,             [true, true, false, false])
      verifyDID(c, 4.81f+2.41f+1.21f,       [true, true, true, false])
      verifyDID(c, 4.81f+2.41f+1.21f+0.61f, [true, true, true, true])
    }
  }

  private Void verifyDID(DigitalInputDemux c, Float in, Bool[] expected)
  {
    setAndExec(c, "in", sn(in))
    verifyEq(c.out1, sb(expected[0]))
    verifyEq(c.out2, sb(expected[1]))
    verifyEq(c.out3, sb(expected[2]))
    verifyEq(c.out4, sb(expected[3]))
  }
}