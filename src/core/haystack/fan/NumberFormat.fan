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
    ["U#,###.00", "U#,###.00;(U#)", "#,##0"].each |p|
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
  }

  private new makePattern(Str srcPattern)
  {
    this.srcPattern   = srcPattern
    this.floatPattern = toFloatPattern(srcPattern)
    this.isBytes      = srcPattern == "B"

    semicolon := srcPattern.index(";")
    if (semicolon == null)
    {
      this.posPrefix = toPrefix(srcPattern)
      this.posSuffix = toSuffix(srcPattern)

      if (!posPrefix.contains("U") && !posSuffix.contains("U"))
        posSuffix = posSuffix + "U"

      this.negPrefix = "-" + posPrefix
      this.negSuffix = posSuffix
    }
    else
    {
      posPattern := srcPattern[0 ..< semicolon].trim
      negPattern := srcPattern[semicolon+1 .. -1].trim
      this.posPrefix = toPrefix(posPattern)
      this.posSuffix = toSuffix(posPattern)
      this.negPrefix = toPrefix(negPattern)
      this.negSuffix = toSuffix(negPattern)
    }
  }

  private static Str toFloatPattern(Str s)
  {
    a := 0
    while (a < s.size && !isPatternChar(s[a])) a++
    b := a
    while (b < s.size && isPatternChar(s[b])) b++
    return s[a..<b]
  }

  private static Str toPrefix(Str s)
  {
    c := 0
    while (c < s.size && !isPatternChar(s[c])) c++
    return s[0..<c]
  }

  private static Str toSuffix(Str s)
  {
    c := s.size-1
    while (c >= 0 && !isPatternChar(s[c])) c--
    return s[c+1..-1]
  }

  private static Bool isPatternChar(Int ch)
  {
    return ch == '#' || ch == '0' || ch == '.' || ch == ','
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

    // build up string with prefix / suffix pattern
    buf := StrBuf(str.size + 8)
    add(buf, neg ? negPrefix : posPrefix, unit)
    buf.add(str)
    add(buf, neg ? negSuffix : posSuffix, unit)
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

  private Void add(StrBuf buf, Str pattern, Unit? unit)
  {
    pattern.each |ch|
    {
      if (ch == 'U')
      {
        if (unit != null)
        {
          symbol := unit.symbol
          if (symbol[0] == '_') symbol = symbol[1..-1]
          buf.add(symbol)
        }
      }
      else
      {
        buf.addChar(ch)
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
  private const Str posPrefix := ""
  private const Str posSuffix := "U"
  private const Str negPrefix := "-"
  private const Str negSuffix := "U"

}

