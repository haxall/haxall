//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Sep 2010  Brian Frank  Creation
//

**
** Number represents a numeric value and an optional Unit.
**
@Js
@Serializable { simple = true }
const final class Number
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Default value is zero with no unit
  static const Number defVal := Number(0f)

  ** Constant for -1 with no unit
  static const Number negOne := Number(-1f)

  ** Constant for 0 with no unit
  static const Number zero   := Number(0f)

  ** Constant for 1 with no unit
  static const Number one    := Number(1f)

  ** Constant for 10 with no unit
  static const Number ten    := Number(10f)

  ** Constant for not-a-number
  static const Number nan    := Number(Float.nan)

  ** Constant for positive infinity
  static const Number posInf := Number(Float.posInf)

  ** Constant for negative infinity
  static const Number negInf := Number(Float.negInf)

  ** Parse from a string according to zinc syntax
  static new fromStr(Str s, Bool checked := true)
  {
    parse(s, false, checked)
  }

  ** Parse from a string but require unit to be only the unit symbol
  @NoDoc static Number? fromStrStrictUnit(Str s, Bool checked := true)
  {
    parse(s, true, checked)
  }

  ** Common code for fromStr and fromStrStrictUnit
  private static Number? parse(Str s, Bool strictUnit, Bool checked)
  {
    msg := "Invalid format"
    c := s.getSafe(0)
    if (c.isDigit || (c == '-' && s.getSafe(1).isDigit))
    {
      try
      {
        tokenizer := HaystackTokenizer(s.in)
        tokenizer.strictUnit = strictUnit
        tokenizer.next
        val := tokenizer.val
        if (tokenizer.next !== HaystackToken.eof) throw Err("Extra tokens")
        if (s[-1].isSpace) throw Err("Extra trailing space")
        if (val is Number) return val
      }
      catch (Err e)
      {
        msg = e.msg
      }
    }
    else
    {
      if (s == "INF")  return Number.posInf
      if (s == "-INF") return Number.negInf
      if (s == "NaN")  return Number.nan
    }
    if (checked) throw ParseErr("Number $s.toCode ($msg)")
    return null
  }

  ** Construct from scalar value and optional unit.
  new make(Float val, Unit? unit := null)
  {
    this.float   = val
    this.unitRef = unit
  }

  ** Construct from scalar integer and optional unit.
  static new makeInt(Int val, Unit? unit := null)
  {
    if (val >= 0 && val < intCache.size && unit == null) return intCache[val]
    return make(val.toFloat, unit)
  }

  ** Construct from scalar Int, Float, or Decimal and optional unit.
  static Number makeNum(Num val, Unit? unit := null) { make(val.toFloat, unit) }

  ** Construct from a duration, standardize unit is hours
  ** If unit is null, then a best attempt is made based on magnitude.
  new makeDuration(Duration dur, Unit? unit := hr)
  {
    if (unit == null)
    {
      if (dur < 1sec) unit = ms
      else if (dur < 1min) unit = sec
      else if (dur < 1hr) unit = mins
      else if (dur < 1day) unit = hr
      else unit = day
    }
    this.float   = dur.ticks.toFloat / 1e9f / unit.scale
    this.unitRef = unit
  }

  // internalized Int cache
  private static const Number[] intCache
  static
  {
    cache := Number[,]
    cacheSize := Env.cur.runtime == "js" ? 5 : 200
    cache.capacity = cacheSize
    for (i:=0; i<cacheSize; ++i) cache.add(Number.make(i.toFloat, null))
    intCache = cache
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  **
  ** Get the scalar value as an Float
  **
  Float toFloat() { float }

  **
  ** Is this number a whole integer without a fractional part
  **
  Bool isInt() { float == float.floor && -1e12f <= float && float <= 1e12f }

  **
  ** Get the scalar value as an Int
  **
  Int toInt() { float.toInt }

  **
  ** Get unit associated with this number or null.
  **
  Unit? unit() { unitRef }

  **
  ** Does this number have a time unit which can be converted
  ** to a Fantom Duration instance.
  **
  Bool isDuration() { toDurationMult != null }

  **
  ** Get this number as a Fantom Duration instance
  **
  Duration? toDuration(Bool checked := true)
  {
    mult := toDurationMult
    if (mult != null) return Duration((float * mult.ticks.toFloat).toInt)
    if (checked) throw UnitErr("Not duration unit: $this")
    return null
  }

  private Duration? toDurationMult()
  {
    if (unit === hr)   return 1hr
    if (unit === mins) return 1min
    if (unit === sec)  return 1sec
    if (unit === day)  return 1day
    if (unit === mo)   return 30day
    if (unit === week) return 7day
    if (unit === year) return 365day
    if (unit === ms)   return 1ms
    if (unit === us)   return 1000ns
    if (unit === ns)   return 1ns
    return null
  }

  **
  ** Get this number as a number of bytes
  **
  @NoDoc Int? toBytes(Bool checked := true)
  {
    mult := -1
    switch (unit?.name)
    {
      case "byte":     mult = 1
      case "kilobyte": mult = 1024
      case "megabyte": mult = 1024*1024
      case "gigabyte": mult = 1024*1024*1024
      case "terabyte": mult = 1024*1024*1024*1024
    }
    if (mult >= 1) return (float * mult.toFloat).toInt
    if (checked) throw UnitErr("Not bytes unit: $this")
    return null
  }

  **
  ** Hash is based on val
  **
  override Int hash() { float.hash }

  **
  ** Equality is based on val and unit.  NaN is equal
  ** to itself (like Float.compare, but unlike Float.equals)
  **
  override Bool equals(Obj? that)
  {
    x := that as Number
    if (x == null) return false
    return float.compare(x.float) == 0 && unit === x.unit
  }

  **
  ** Compare is based on val.
  ** Throw `UnitErr` is this and b have incompatible units.
  **
  override Int compare(Obj that)
  {
    x := (Number)that
    if (unit !== x.unit && unit != null && x.unit != null)
    {
      // allow time comparisons of unlike units
      if (isDuration && x.isDuration)
        return toDuration <=> x.toDuration

      throw UnitErr("$unit <=> $x.unit")
    }
    return float <=> x.float
  }

  **
  ** Return if this number is approximately equal to that - see `sys::Float.approx`
  **
  Bool approx(Number that, Float? tolerance := null)
  {
    if (unit !== that.unit) return false
    return float.approx(that.float, tolerance)
  }

  **
  ** Is this a negative number
  **
  Bool isNegative() { float < 0f }

  **
  ** Is the floating value NaN.
  **
  Bool isNaN() { float.isNaN }

  **
  ** Return if this number if pos/neg infinity or NaN
  **
  Bool isSpecial()
  {
    float == Float.posInf || float == Float.negInf || float.isNaN
  }

  **
  ** String representation
  **
  override Str toStr()
  {
    s := isInt ? toInt.toStr : float.toStr
    if (unit != null && !isSpecial) s += unit.symbol
    return s
  }

  internal Str toJson()
  {
    s := StrBuf(32)
    s.addChar('n').addChar(':')
    if (isInt) s.add(toInt.toStr)
    else s.add(float.toStr)
    if (unit != null && !isSpecial) s.addChar(' ').add(unit.symbol)
    return s.toStr
  }

  **
  ** Trio/zinc code representation, same as `toStr`
  **
  Str toCode() { toStr }

//////////////////////////////////////////////////////////////////////////
// Operators
//////////////////////////////////////////////////////////////////////////

  **
  ** Negate this number.  Shortcut is -a.
  **
  @Operator Number negate() { make(-float, unit) }

  **
  ** Increment this number.  Shortcut is ++a.
  **
  @Operator Number increment() { make(float+1f, unit) }

  **
  ** Decrement this number.  Shortcut is --a.
  **
  @Operator Number decrement() { make(float-1f, unit) }

  **
  ** Add this with b.  Shortcut is a+b.
  ** Throw `UnitErr` is this and b have incompatible units.
  **
  @Operator Number plus(Number b) { make(float + b.float, plusUnit(unit, b.unit)) }

  @NoDoc static Unit? plusUnit(Unit? a, Unit? b)
  {
    if (b == null) return a
    if (a == null) return b
    if (a === b)   return a
    if ((a === F && b === Fdeg) || (a === Fdeg && b === F)) return F
    if ((a === C && b === Cdeg) || (a === Cdeg && b === C)) return C
    throw UnitErr("$a + $b")
  }

  **
  ** Subtract b from this.  Shortcut is a-b.
  ** The b.unit must match this.unit.
  **
  @Operator Number minus(Number b) { make(float - b.float, minusUnit(unit, b.unit)) }

  @NoDoc static Unit? minusUnit(Unit? a, Unit? b)
  {
    if (b == null) return a
    if (a == null) return b
    if (a === F && b === F) return Fdeg
    if (a === C && b === C) return Cdeg
    if (a === F && b === Fdeg) return F
    if (a === C && b === Cdeg) return C
    if (a === b)   return a
    throw UnitErr("$a - $b")
  }

  **
  ** Multiple this and b.  Shortcut is a*b.
  ** The resulting unit is derived from the product of this and b.
  ** Throw `UnitErr` if a*b does not match a unit in the unit database.
  **
  @Operator Number mult(Number b) { make(float * b.float, multUnit(unit, b.unit)) }

  @NoDoc static Unit? multUnit(Unit? a, Unit? b)
  {
    if (b == null) return a
    if (a == null) return b
    try
      return  a * b
    catch
      return defineUnit(a, '_', b)
  }

  **
  ** Divide this by b.  Shortcut is a/b.
  ** The resulting unit is derived from the quotient of this and b.
  ** Throw `UnitErr` if a/b does not match a unit in the unit database.
  **
  @Operator Number div(Number b) { make(float / b.float, divUnit(unit, b.unit)) }

  @NoDoc static Unit? divUnit(Unit? a, Unit? b)
  {
    if (b == null) return a
    if (a == null) return b
    try
      return a / b
    catch
      return defineUnit(a, '/', b)
  }

  **
  ** Return remainder of this divided by b.  Shortcut is a%b.
  ** The unit of b must be null.
  **
  @Operator Number mod(Number b)
  {
    if (b.unit != null) throw UnitErr("$unit % $b")
    return make(float % b.float, unit)
  }

  private static Unit defineUnit(Unit a, Int symbol, Unit b)
  {
    // build up new string _a/b or _a_b
    s := StrBuf()
    aStr := a.toStr
    if (aStr.startsWith("_")) s.add(aStr)
    else s.addChar('_').add(aStr)

    s.addChar(symbol)

    bStr := b.toStr
    if (bStr.startsWith("_")) bStr = bStr[1..-1]
    s.add(bStr)

    // define if not created yet
    str := s.toStr
    unit := Unit.fromStr(str, false)
    if (unit == null) unit = Unit.define(str)
    return unit
  }

  @NoDoc static Unit? loadUnit(Str str, Bool checked := false)
  {
    unit := Unit.fromStr(str, false)
    if (unit != null) return unit

    if (!str.isEmpty && str[0] == '_')
    {
      // try and define a custom unit, but there is a potential
      // race condition b/w first fromStr and Unit.define, so
      // on error we just return
      try
        return Unit.define(str)
      catch (Err e)
        return Unit.fromStr(str, checked)
    }

    if (checked) throw Err("Unit not defined: $str.toCode")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  **
  ** Return absolute value of this number.
  **
  Number abs()
  {
    float >= 0f ? this : make(-float, unit)
  }

  **
  ** Return min value.  Units are **not** checked for this comparison.
  **
  Number min(Number that)
  {
    // using <=> to ensure correct behavior with NaN
    (float <=> that.float) <= 0 ? this : that
  }

  **
  ** Return max value.  Units are **not** checked for this comparison.
  **
  Number max(Number that)
  {
    // using <=> to ensure correct behavior with NaN
    (float <=> that.float) >= 0 ? this : that
  }

  **
  ** Clamp this number between the min and max.  If its less than min then
  ** return min, if its greater than max return max, otherwise return this
  ** number itself.  The min and max must have matching units or be unitless.
  ** The result is always in the same unit as this instance.
  **
  Number clamp(Number min, Number max)
  {
    if ((this.unit !== min.unit && min.unit != null) ||
        (this.unit !== max.unit && max.unit != null))
      throw UnitErr("clamp($this, $min, $max)")

    if ((this.float <=> min.float) < 0)
    {
      if (this.unit === min.unit) return min
      return Number(min.float, this.unit)
    }

    if ((this.float <=> max.float) > 0)
    {
      if (this.unit === max.unit) return max
      return Number(max.float, this.unit)
    }

    return this
  }

  **
  ** Get the ASCII upper case version of this number as a Unicode point.
  **
  Number upper()
  {
    int := toInt
    up := int.upper
    if (int == up) return this
    return makeInt(up, unit)
  }

  **
  ** Get the ASCII lower case version of this number as a Unicode point.
  **
  Number lower()
  {
    int := toInt
    lo := int.lower
    if (int == lo) return this
    return makeInt(lo, unit)
  }

  **
  ** Format the number using given pattern which is an superset
  ** of `sys::Float.toLocale`:
  **
  **   #        optional digit
  **   0        required digit
  **   .        decimal point
  **   ,        grouping separator (only last one before decimal matters)
  **   U        position of unit (default to suffix)
  **   pos;neg  separate negative format (must specify U position)
  **
  ** When using the 'pos;neg' pattern, the "U" position must be specified in both
  ** pos and neg patterns, otherwise the unit is omitted. Note that the negative
  ** pattern always uses mimics the positive pattern for the actual digit
  ** formatting (#, 0, decimal, and grouping).
  **
  ** The special "B" pattern is used to format bytes; see `sys::Int.toLocale`.
  **
  ** If pattern is null, the following rules are used:
  **   1. If `isDuration` true, then return best fit unit is selected
  **   2. If unit is non-null attempt to lookup a unit specific default pattern
  **      with the locale key "haystack::number.{unit.name}".
  **   3. If `isInt` true, then return `sys::Int.toLocale` using sys locale default
  **   4. Return `sys::Float.toLocale` using sys locale default
  **
  ** Examples:
  **   Number   Pattern        Result    Notes
  **   ------   -------        -------   ------
  **   12.34    "#.####"       12.34     Optional fractional digits
  **   12.34    "#.0000"       12.3400   Required fractional digits
  **   12.34$   null           $12.34    Haystack locale default
  **   12$      "U 0.00"       $ 12.00   Explicit unit placement
  **   -12$     "U0.##;(U#)"   ($12)     Alternative negative format
  **   45%      "+0.0U;-0.0U"  +45%      Use leading positive sign
  **
  Str toLocale(Str? pattern := null)
  {
    NumberFormat.make(pattern).format(this)
  }

//////////////////////////////////////////////////////////////////////////
// Private
//////////////////////////////////////////////////////////////////////////

  @NoDoc const static Unit F       := constUnit("fahrenheit")
  @NoDoc const static Unit C       := constUnit("celsius")
  @NoDoc const static Unit Fdeg    := constUnit("fahrenheit_degrees")
  @NoDoc const static Unit Cdeg    := constUnit("celsius_degrees")
  @NoDoc const static Unit FdegDay := constUnit("degree_days_fahrenheit")
  @NoDoc const static Unit CdegDay := constUnit("degree_days_celsius")
  @NoDoc const static Unit ns      := constUnit("ns")
  @NoDoc const static Unit us      := constUnit("µs")
  @NoDoc const static Unit ms      := constUnit("ms")
  @NoDoc const static Unit sec     := constUnit("s")
  @NoDoc const static Unit mins    := constUnit("min")
  @NoDoc const static Unit hr      := constUnit("h")
  @NoDoc const static Unit day     := constUnit("day")
  @NoDoc const static Unit week    := constUnit("wk")
  @NoDoc const static Unit mo      := constUnit("mo")
  @NoDoc const static Unit year    := constUnit("year")
  @NoDoc const static Unit percent := constUnit("%")
  @NoDoc const static Unit dollar  := constUnit("\$")
  @NoDoc const static Unit byte    := constUnit("byte")

  private static Unit constUnit(Str name)
  {
    Unit.fromStr(name, false) ?: Unit.define(name)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Numeric value
  private const Float float

  ** Optional number
  private const Unit? unitRef

}

