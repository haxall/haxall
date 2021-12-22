//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  23 Apr 2021   Matthew Giannini  Creation
//

class TopicTest : Test
{
  Void testNames()
  {
    ["/", "\$SYS", "/foo", "/foo/"].each |name|
    {
      Topic.validateName(name)
      verify(true)
    }

    ["+", "#", "/foo/+", "/foo/#"].each |name|
    {
      verifyErr(MqttErr#) { Topic.validateName(name) }
    }
  }

  Void testFilters()
  {
    ["#", "sport/tennis/player1/#", "sport/#",
     "+", "+/tennis/#", "sport/+/player1", "+/+", "/+"].each |filter|
    {
      Topic.validateFilter(filter)
      verify(true)
    }

    ["sport/tennis#", "sport/tennis/#/ranking",
     "sport+", "+sport", "sp+ort", "s+/", "/+sport"].each |filter|
    {
      verifyErr(MqttErr#) { Topic.validateFilter(filter) }
    }
  }

  Void testMatch()
  {
    verify(Topic.matches("/", "/"))
    verify(Topic.matches("/a", "/a"))
    verify(Topic.matches("a/b", "a/b"))

    verify(Topic.matches("sport/tennis/player1", "sport/tennis/player1/#"))
    verify(Topic.matches("sport/tennis/player1/ranking", "sport/tennis/player1/#"))
    verify(Topic.matches("sport/tennis/player1/score/wimbledon", "sport/tennis/player1/#"))
    verify(Topic.matches("sport", "sport/#"))
    verify(Topic.matches("/", "#"))
    verify(Topic.matches("foo", "#"))

    verify(Topic.matches("sport/tennis/player1", "sport/tennis/+"))
    verify(Topic.matches("sport/", "sport/+"))

    verifyFalse(Topic.matches("/a", "a"))
    verifyFalse(Topic.matches("a/", "a"))
    verifyFalse(Topic.matches("sport/tennis/player1/ranking", "sport/tennis/+"))
    verifyFalse(Topic.matches("sport", "sport/+"))
    verifyFalse(Topic.matches("/test1/foo", "/test2/#"))
    verifyFalse(Topic.matches("/test1", "/test2"))
  }
}
