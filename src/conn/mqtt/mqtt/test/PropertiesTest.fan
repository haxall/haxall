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

  private Properties makeTestProps()
  {
    props := Properties()
    props.add(Property.userProperty, StrPair("foo", "bar"))
    props.add(Property.userProperty, StrPair("baz", "qaz"))
    return props
  }
}