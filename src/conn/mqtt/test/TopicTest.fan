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
     "+", "+/tennis/#", "sport/+/player1", "+/+", "/+",
     "\$share/g/a/b", "\$share/g/#", "\$share/g/+/b", "\$share/g//a"].each |filter|
    {
      Topic.validateFilter(filter)
      verify(true)
    }

    ["sport/tennis#", "sport/tennis/#/ranking",
     "sport+", "+sport", "sp+ort", "s+/", "/+sport",
     "\$share/g", "\$share/g/", "\$share//a", "\$share/+/a", "\$share/g#/a",
     "\$share/g/a#"].each |filter|
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

    // whitespace is significant
    verify(Topic.matches("a/ b", "a/ b"))
    verify(Topic.matches("a/ b", "a/+"))
    verifyFalse(Topic.matches("a/ b", "a/b"))
    verifyFalse(Topic.matches("a/b ", "a/b"))
    verifyFalse(Topic.matches(" a/b/c", "a/+/c"))

    // wildcards in the first level do not match '$' topics
    verifyFalse(Topic.matches("\$SYS/broker/uptime", "#"))
    verifyFalse(Topic.matches("\$SYS/broker/uptime", "+/broker/uptime"))
    verifyFalse(Topic.matches("\$SYS", "+"))
    verify(Topic.matches("\$SYS/broker/uptime", "\$SYS/#"))
    verify(Topic.matches("\$SYS/broker/uptime", "\$SYS/+/uptime"))
    verify(Topic.matches("a/\$b", "a/+"))

    // shared subscriptions match on their topic filter
    verify(Topic.matches("a/b", "\$share/g/a/b"))
    verify(Topic.matches("a/b", "\$share/g/a/+"))
    verify(Topic.matches("a/b/c", "\$share/g/#"))
    verifyFalse(Topic.matches("a/c", "\$share/g/a/b"))
    verifyFalse(Topic.matches("g/a/b", "\$share/g/a/b"))
    verifyFalse(Topic.matches("\$SYS/x", "\$share/g/#"))
  }
}
