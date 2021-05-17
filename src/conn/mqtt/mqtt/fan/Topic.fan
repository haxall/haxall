//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  12 Apr 2021   Matthew Giannini  Creation
//

**
** MQTT Topic
**
const class Topic
{
  private static const Int sep     := '/'
  private static const Int multi   := '#'
  private static const Int single  := '+'
  private static const Int max_len := 65_535

  ** Validate that this is a valid topic name - it must not contain
  ** any wildcard characters. Returns the name.
  static Str validateName(Str name)
  {
    validateNameOrFilter(name)
    hasWild := name.any |ch| { ch == multi || ch == single }
    if (!hasWild) return name
    throw MqttErr("Topic name must not contain wildcards: $name")
  }

  ** Validate that this is a valid topic filter and return it.
  static Str validateFilter(Str topic)
  {
    validateNameOrFilter(topic)

    // // multi-level wildcard checks
    // if (topic == "#") return
    // idx := topic.index(multi.toChar)
    // if (idx != null)
    // {
    //   if (idx != topic.size - 1)
    //     throw MqttErr("The multi-level wildcard must be the last character: $topic")
    //   if (topic.getSafe(idx - 1) != sep)
    //     throw MqttErr("A multi-level wildcard not specified on its own must follow a topic level separator: $topic")
    // }

    pos       := -1
    Int? prev := null
    Int? cur  := null
    chars     := topic.chars
    while (true)
    {
      ++pos
      if (pos >= chars.size) break

      prev = cur
      cur  = topic[pos]
      if (cur == multi)
      {
        if (pos != topic.size - 1)
          throw MqttErr("The multi-level wildcard must be the last character: $topic")
        if (pos > 0 && prev != sep)
          throw MqttErr("A multi-level wildcard not specified on its own must follow a topic level separator: $topic")
      }
      else if (cur == single)
      {
        after := chars.getSafe(pos+1)
        if (pos == 0)
        {
          // "+"
          if (after == null) break
        }
        if ((prev != null && prev != sep) || (after != null && after != sep))
          throw MqttErr("A single-level wildcard must occupy an entire level: $topic")
      }
    }

    return topic
  }

  private static Void validateNameOrFilter(Str val)
  {
    if (val.isEmpty) throw MqttErr("Topics names and filters must contain at least one character")
    if (val.containsChar(0)) throw MqttErr("Topic names and filters must not contain the null character")
    if (val.toBuf.size > max_len) throw MqttErr("Topic names and filters must be no more than ${max_len} bytes")
  }

  ** Return true if the topic matches the filter.
  static Bool matches(Str topic, Str filter)
  {
    try
    {
      validateName(topic)
      validateFilter(filter)
    }
    catch (Err err)
    {
      return false
    }

    // quick check for exact match
    if (topic == filter) return true

    tparts := topic.split(sep)
    fparts := filter.split(sep)
    i := 0
    while (i < tparts.size)
    {
      tpart := tparts[i]
      fpart := fparts.getSafe(i)
      ++i

      if (tpart == fpart) continue

      if (fpart == single.toChar) continue

      if (fpart == multi.toChar) return true
    }


    // check for topic shorter than filter, but next part of filter is mult-level wildcard
    // a/b/c matches a/b/c/#
    if (tparts.size != fparts.size)
    {
      if (tparts.size + 1 != fparts.size) return false
      if (fparts[-1] != multi.toChar) return false
    }

    // if we get here we had a match
    return true
  }
}

