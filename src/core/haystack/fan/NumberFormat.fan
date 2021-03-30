//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Aug 2019  Brian Frank  Creation
//

**
** NumberFormat handles Number.toLocale patterns
**
@NoDoc @Js
const class NumberFormat
{

//////////////////////////////////////////////////////////////////////////
// Factory
//////////////////////////////////////////////////////////////////////////

  static new make(Str? s)
  {
    if (s == null) return empty
    cached := predefined[s]
    if (cached != null) return cached
    return makePattern(s)
  }

  private static const Str:NumberFormat predefined
  private static const NumberFormat empty := makeEmpty
  static
  {
    acc := Str:NumberFormat[:]
    ["U#,###.00", "U#,###.00;(#)", "#,##0"].each |p|
    {
      acc[p] = makePattern(p)
    }
    predefined = acc
  }

//////////////////////////////////////////////////////////////////////////
// Private Constructors
//////////////////////////////////////////////////////////////////////////

  private new makeEmpty()
  {
    this.srcPattern = null
    this.floatPattern = null
    this.isBytes = false
    this.negPrefix = "-"
    this.negSuffix = ""
    this.unitPattern = "U"
    this.unitIsPrefix = false
  }

  private new makePattern(Str srcPattern)
  {
    p := srcPattern
    negPrefix := "-"
    negSuffix := ""
    unitPattern := "U"
    unitIsPrefix := false

    semi := p.index(";")
    if (semi != null)
    {
      neg := p[semi+1..-1].trim
      p = p[0..<semi].trim
      negPrefix = prefix(neg, true)
      negSuffix = suffix(neg, true)
    }

    if (p.contains("U"))
    {
      unitPattern = prefix(p, false)
      if (!unitPattern.isEmpty)
      {
        p = p[unitPattern.size+1..-1]
        unitIsPrefix = true
      }
      else
      {
        unitPattern = suffix(p, false)
        p = p[0..p.size-unitPattern.size-1]
        unitIsPrefix = false
      }
    }

    this.srcPattern = srcPattern
    this.floatPattern = p
    this.isBytes = p == "B"
    this.negPrefix = negPrefix
    this.negSuffix = negSuffix
    this.unitIsPrefix = unitIsPrefix
    this.unitPattern = unitPattern
  }

  private static Str prefix(Str s, Bool includeU)
  {
    c := 0
    while (c < s.size && !isPatternChar(s[c], includeU)) c++
    return s[0..<c]
  }

  private static Str suffix(Str s, Bool includeU)
  {
    c := s.size-1
    while (c >= 0 && !isPatternChar(s[c], includeU)) c--
    return s[c+1..-1]
  }

  private static Bool isPatternChar(Int ch, Bool includeU)
  {
    if (ch == 'U') return includeU
    return ch == '#' || ch == '0' || ch == '.' || ch == ',' || ch > 128
  }

//////////////////////////////////////////////////////////////////////////
// Format
//////////////////////////////////////////////////////////////////////////

  Str format(Number num)
  {
    // special handling
    if (floatPattern == null && isDuration(num)) return formatDuration(num.toDuration)
    if (isBytes) return num.toInt.toLocale("B")

    // check negative
    float := num.toFloat
    neg := float < 0f
    if (neg) float = -float

    // if pattern null, check for unit default
    unit := num.unit
    pattern := floatPattern
    if (unit != null && pattern == null)
    {
      pattern = typeof.pod.locale("number." + unit.name, null)
      if (pattern != null) return make(pattern).format(num)
    }

    // format int/float using pattern
    str := num.isInt ?
      float.toInt.toLocale(pattern) :
      float.toLocale(pattern)

    // if unit is null and not negative we are done
    if (unit == null && !neg) return str

    // build up string with negative and unit formatting
    hasUnit := unit != null
    buf := StrBuf(str.size + 8)
    if (neg) buf.add(negPrefix)
    if (hasUnit && unitIsPrefix) addUnit(buf, unit)
    buf.add(str)
    if (hasUnit && !unitIsPrefix) addUnit(buf, unit)
    if (neg) buf.add(negSuffix)
    return buf.toStr
  }

  private Bool isDuration(Number num)
  {
    // only format duration for units less than day specially
    unit := num.unit
    if (unit == null) return false
    return unit === Number.hr   ||
           unit === Number.mins ||
           unit === Number.sec  ||
           unit === Number.ms   ||
           unit === Number.ns
  }

  private Str formatDuration(Duration dur)
  {
    abs := dur.abs
    ticks := dur.ticks.toFloat
    pattern := "0.##"
    if (dur == 0sec) return "0"
    if (abs < 1ms)  return dur.toLocale
    if (abs < 1sec) return (ticks/1ms.ticks.toFloat).toLocale(pattern)+"$<sys::msAbbr>"
    if (abs < 1min) return (ticks/1sec.ticks.toFloat).toLocale(pattern)+"$<sys::secAbbr>"
    if (abs < 1hr)  return (ticks/1min.ticks.toFloat).toLocale(pattern)+"$<sys::minAbbr>"
    if (abs < 1day) return (ticks/1hr.ticks.toFloat).toLocale(pattern)+"$<sys::hourAbbr>"
    return (ticks/1day.ticks.toFloat).toLocale(pattern)+"$<sys::dayAbbr>"
  }

  private Void addUnit(StrBuf buf, Unit? unit)
  {
    if (unit == null) return

    symbol := unit.symbol
    if (symbol[0] == '_') symbol = symbol[1..-1]

    if (unitPattern=="U")
    {
      buf.add(symbol)
    }
    else
    {
      unitPattern.each |ch|
      {
        if (ch == 'U') buf.add(symbol)
        else buf.addChar(ch)
      }
    }
  }

  override Str toStr() { "NumberFormat($srcPattern)" }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Str? srcPattern
  private const Str? floatPattern
  private const Bool isBytes
  private const Str negPrefix := "-"
  private const Str negSuffix := ""
  private const Str unitPattern
  private const Bool unitIsPrefix

}

