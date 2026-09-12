//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    2 Aug 2024  Brian Frank  Creation
//   12 Sep 2026  Brian Frank  Move from ion
//

using xeto
using haystack

**
** ItemStatus captures status level icon/color pairs
**
@Js
enum class ItemStatus
{
  abnormal   ("purple", "triangle-alert"),
  alarm      ("red",    "bell"),
  disabled   ("gray",   "ban"),
  down       ("amber",  "triangle-alert"),
  err        ("red",    "circle-x"),
  fault      ("red",    "circle-x"),
  info       ("blue",   "info"),
  nil        ("gray",   "circle-off"),
  ok         ("green",  "check"),
  overridden ("purple", "clock"),
  pending    ("blue",   "hourglass"),
  stale      ("amber",  "check"),
  syncing    ("purple", "refresh-cw"),
  warn       ("amber",  "triangle-alert"),
  unacked    ("green",  "bell"),
  unknown    ("gray",   "circle-question-mark")


  private new make(Str colorName, Str iconName)
  {
    this.colorName = colorName
    this.iconName = iconName
  }

  ** Coerce a string or dict flags to a status
  @NoDoc static ItemStatus coerce(Obj x)
  {
    if (x is Dict)
    {
      // {flag, flag} or {} is ok
      res := ((Dict)x).eachWhile |v, n|
      {
        if (v === Marker.val) return find(n)
        return null
      }
      return res ?: ok
    }
    return find(x.toStr) ?: unknown
  }

  ** Map common status flag name to its standardized status color.
  ** This handles hx.control/Niagara status flags and ph::curStatus
  @NoDoc static ItemStatus? find(Str n)
  {
    strMap.get(n)
  }

  private static once Str:ItemStatus strMap()
  {
    acc := Str:ItemStatus[:]

    // my own enums
    vals.each |v| { acc[v.name] = v }

    // hx.control/Niagara status flags
    acc["ok"]           = ok
    acc["alarm"]        = alarm
    acc["disabled"]     = disabled
    acc["down"]         = down
    acc["fault"]        = fault
    acc["null"]         = nil
    acc["overridden"]   = overridden
    acc["stale"]        = stale
    acc["unacked"]      = unacked
    acc["alarmUnacked"] = unacked

    // curStatus
    acc["unknown"]        = unknown
    acc["remoteDown"]     = down
    acc["remoteDisabled"] = disabled
    acc["remoteFault"]    = fault
    acc["remoteUnknown"]  = unknown

    // misc
    acc["draft"]   = warn
    acc["pending"] = pending
    acc["syncing"] = syncing

    return acc.toImmutable
  }

  private const Str colorName
  private const Str iconName

  once ColorName color() { ColorName.fromStr(colorName) }

  once Icon icon() { Icon(iconName) }

  @NoDoc Item toItem(Str text)
  {
    Item(text, icon, text, Etc.dict1("color", color))
  }
}

