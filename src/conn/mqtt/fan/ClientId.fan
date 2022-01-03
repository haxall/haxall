//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  15 Apr 2021   Matthew Giannini  Creation
//

using util

**
** Client identifier utilities
**
const mixin ClientId
{
  ** Generate a client identifier that MUST be accepted by any compliant MQTT server
  static Str gen()
  {
    rand  := Random.makeSecure
    chars := List(Int#, max_safe_len)
    max_safe_len.times |x|
    {
      chars.add(safe_chars[rand.next(0..<safe_chars.size)])
    }
    return Str.fromChars(chars)
  }

  ** All MQTT servers must accept client identifiers up to this length
  private static const Int max_safe_len := 23

  ** Characters that every MQTT server must accept
  private static const Str safe_chars := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
}