//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  31 Mar 2021   Matthew Giannini  Creation
//

class PropertiesTest : Test
{
  Void test()
  {
    verify(Properties().isEmpty)

    props := makeTestProps
    verifyEq(props[Property.userProperty], StrPair[StrPair("foo","bar"), StrPair("baz","qaz")])
  }

  Void testRange()
  {
    // data type range applies to properties with their own range check
    verifyErr(ArgErr#) { Properties().add(Property.receiveMax, 0) }
    verifyErr(ArgErr#) { Properties().add(Property.receiveMax, -1) }
    verifyErr(ArgErr#) { Properties().add(Property.receiveMax, 0x1_0000) }
    verifyErr(ArgErr#) { Properties().add(Property.topicAlias, 0x1_0000) }
    verifyErr(ArgErr#) { Properties().add(Property.maxPacketSize, 0x1_0000_0000) }
    verifyErr(ArgErr#) { Properties().add(Property.maxQoS, 2) }
    verifyErr(ArgErr#) { Properties().add(Property.subscriptionId, 0) }

    props := Properties()
      .add(Property.receiveMax, 0xFFFF)
      .add(Property.topicAlias, 1)
      .add(Property.maxPacketSize, 0xFFFF_FFFF)
      .add(Property.maxQoS, 1)
    verifyEq(props[Property.receiveMax], 0xFFFF)
    verifyEq(props[Property.maxPacketSize], 0xFFFF_FFFF)
  }

  private Properties makeTestProps()
  {
    props := Properties()
    props.add(Property.userProperty, StrPair("foo", "bar"))
    props.add(Property.userProperty, StrPair("baz", "qaz"))
    return props
  }
}