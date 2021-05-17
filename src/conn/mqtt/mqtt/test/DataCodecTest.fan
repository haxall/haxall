//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  31 Mar 2021   Matthew Giannini  Creation
//

class DataCodecTest : Test, DataCodec
{
  Void testUtf8()
  {
    buf := Buf()

    writeUtf8("", buf)
    verifyEq("", readUtf8(buf.flip))

    writeUtf8("mqtt", buf.clear)
    verifyEq("mqtt", readUtf8(buf.flip))

    writeUtf8("ἐν ἀρχῇ ἦν ὁ λόγος", buf.clear)
    verifyEq("ἐν ἀρχῇ ἦν ὁ λόγος", readUtf8(buf.flip))
  }

  Void testVariableByteInteger()
  {
    buf := Buf()

    writeVbi(0, buf)
    verifyEq(0, readVbi(buf.flip))

    writeVbi(127, buf.clear)
    verifyEq(127, readVbi(buf.flip))

    writeVbi(128, buf.clear)
    verifyEq(128, readVbi(buf.flip))

    writeVbi(16_383, buf.clear)
    verifyEq(16_383, readVbi(buf.flip))

    writeVbi(16_384, buf.clear)
    verifyEq(16_384, readVbi(buf.flip))

    writeVbi(2_097_151, buf.clear)
    verifyEq(2_097_151, readVbi(buf.flip))

    writeVbi(2_097_152, buf.clear)
    verifyEq(2_097_152, readVbi(buf.flip))

    writeVbi(268_435_455, buf.clear)
    verifyEq(268_435_455, readVbi(buf.flip))
  }

  Void testBinary()
  {
    buf := Buf()

    writeBin(Buf(), buf)
    verifyEq(0, readBin(buf.flip).size)

    writeBin("mqtt".toBuf, buf.clear)
    verifyEq("mqtt", readBin(buf.flip).readAllStr)
  }

  Void testStrPair()
  {
    buf := Buf()

    writeStrPair(StrPair("foo", "bar"), buf)
    verifyEq(StrPair("foo", "bar"), readStrPair(buf.flip))
  }

  Void testProperties()
  {
    buf := Buf()

    writeProps(Properties(), buf)
    verify(readProps(buf.flip).isEmpty)

    props := Properties()
    props.add(Property.payloadFormatIndicator, 1)      // byte
    props.add(Property.receiveMax, 1024)               // byte2
    props.add(Property.maxPacketSize, 1024*1024*1024)  // byte4
    props.add(Property.contentType, "text/plain")      // utf8
    props.add(Property.authData, "password".toBuf)     // binary
    props.add(Property.userProperty, StrPair("a","A")) // StrPair
    props.add(Property.userProperty, StrPair("b","B")) // StrPair

    writeProps(props, buf.clear)
    decoded := readProps(buf.flip)
    verifyEq(1, decoded[Property.payloadFormatIndicator])
    verifyEq(1024, decoded[Property.receiveMax])
    verifyEq(1024*1024*1024, decoded[Property.maxPacketSize])
    verifyEq("text/plain", decoded[Property.contentType])
    verifyEq("password".toBuf.toHex, decoded[Property.authData]->toHex)
    verifyEq([StrPair("a","A"), StrPair("b","B")], decoded[Property.userProperty])
  }
}