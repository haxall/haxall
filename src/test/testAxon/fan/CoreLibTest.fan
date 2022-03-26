//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2009  Brian Frank  Creation
//   14 Apr 2016  Brian Frank  Port to 3.0
//

using haystack
using axon

**
** CoreLibTest
**
@Js
class CoreLibTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Date
//////////////////////////////////////////////////////////////////////////

  Void testDateSpans()
  {
    today := Date.today
    yesterday := today - 1day
    pastMon := today.month.decrement

    DateTime now := eval("core::now()")
    verify(DateTime.now(null) - now < 300ms)
    verifyEval("today()", today)
    verifyEval("core::yesterday()", today - 1day)

    verifyEval("thisWeek()", DateSpan.thisWeek)
    verifyEval("thisMonth()", DateSpan.thisMonth)
    verifyEval("thisQuarter()", DateSpan.thisQuarter)
    verifyEval("thisYear()", DateSpan.thisYear)

    verifyEval("pastWeek()", DateSpan.pastWeek)
    verifyEval("pastMonth()", DateSpan.pastMonth)
    verifyEval("pastMonth().start.month", n(pastMon.ordinal + 1, "mo"))
    verifyEval("pastMonth().end", today)
    verifyEval("pastYear()", DateSpan.pastYear)

    verifyEval("lastWeek()", DateSpan.lastWeek)
    verifyEval("lastMonth()", DateSpan.lastMonth)
    verifyEval("lastQuarter()", DateSpan.lastQuarter)
    verifyEval("lastYear()", DateSpan.lastYear)

    verifyEval("(${today}).occurred(today)", true)
    verifyEval("now().occurred(today)", true)
    verifyEval("today().occurred(yesterday)", false)
    verifyEval("now().occurred(yesterday)", false)
    verifyEval("(${yesterday}).occurred(yesterday)", true)
    verifyEval("yesterday().occurred(today)", false)
    verifyEval("yesterday().occurred(pastWeek)", true)
    verifyEval("yesterday().occurred(pastMonth())", true)
    verifyEval("2010-01-04.occurred(2010-01-05..2010-01-07)", false)
    verifyEval("2010-01-05.occurred(2010-01-05..2010-01-07)", true)
    verifyEval("2010-01-06.occurred(2010-01-05..2010-01-07)", true)
    verifyEval("2010-01-07.occurred(2010-01-05..2010-01-07)", true)
    verifyEval("2010-01-08.occurred(2010-01-05..2010-01-07)", false)

    verifyDateSpan("2010-07-01..2010-07-03", "2010-07-01", "2010-07-03")
    verifyDateSpan("2010-07-01..60day",      "2010-07-01", "2010-08-29")
    verifyDateSpan("2010-07-08",             "2010-07-08", "2010-07-08")
    verifyDateSpan("2010-07",                "2010-07-01", "2010-07-31")
    verifyDateSpan("2010",                   "2010-01-01", "2010-12-31")
    verifyDateSpan("pastWeek",               today.plus(-7day).toStr, today.toStr)
    verifyDateSpan("today",                  today.toStr, today.toStr)
    verifyDateSpan("now()..now()",           today.toStr, today.toStr)

    verifyEval("2010-12 + 1day", DateSpan(Date("2010-12-02"), Date("2011-01-01")))
    verifyEval("(2010-10-01..2010-10-04) - 2day", DateSpan(Date("2010-09-29"), Date("2010-10-02")))

    s := """dateTime(parseDate("2010-07-02"), parseTime("02:30"), "New_York")"""
    e := """dateTime(parseDate("2010-07-03"), parseTime("13:45"), "New_York")"""
    verifyDateSpan("${s}..${e}", "2010-07-02", "2010-07-03")

    s = """dateTime(parseDate("2010-07-02"), parseTime("00:00"), "New_York")"""
    e = """dateTime(parseDate("2010-07-05"), parseTime("00:00"), "New_York")"""
    verifyDateSpan("${s}..${e}", "2010-07-02", "2010-07-04")

    verifyEval("2010-01.contains(2010-01-01)", true)
    verifyEval("2010-01.contains(2009-12-31)", false)
    verifyEval("(2010-01-01..2010-01-31).contains(2010-01-31)", true)
    verifyEval("(2010-01-01..2010-01-31).contains(2010-02-01)", false)
  }

  Void verifyDateSpan(Str range, Str start, Str end)
  {
    s := Date(start)
    e := Date(end)
    DateSpan x := eval("toDateSpan($range)")
    verifyEq(x.start, s)
    verifyEq(x.end, e)

    acc := (Obj?[])evalBlock("x: []; eachDay($range, d => x = x.add(d)); x")
    verifyEq(acc.first, s)
    verifyEq(acc.last, e)
    verifyEq(acc.size, x.numDays)
  }

  Void testEachMonth()
  {
    acc := (Obj?[])evalBlock("x: []; eachMonth(2008-02-03, d => x = x.add(d)); x")
    verifyEq(acc, Obj?[DateSpan.makeMonth(2008, Month.feb)])

    acc = evalBlock("x: []; eachMonth(2010, d => x = x.add(d)); x")
    verifyEq(acc.size, 12)
    verifyEq(acc[0],  DateSpan.makeMonth(2010, Month.jan))
    verifyEq(acc[11], DateSpan.makeMonth(2010, Month.dec))
  }

  Void testSpan()
  {
    today := Date.today
    yesterday := today - 1day
    m := Time(0, 0)
    tz := TimeZone("Chicago")

    verifySpan("""toSpan(today, "Chicago")""",
      today.midnight(tz),
      today.plus(1day).midnight(tz))

    verifySpan("""toSpan(today(), "Chicago")""",
      today.midnight(tz),
      today.plus(1day).midnight(tz))

    verifySpan("""toSpan(dateTime(today(), 2:00, "Chicago") .. dateTime(today(), 3:15, "Chicago"))""",
      today.toDateTime(Time(2, 0), tz),
      today.toDateTime(Time(3, 15), tz))

    verifySpan("""toSpan(today(), "Chicago").toTimeZone("Denver")""",
      today.midnight(tz).toTimeZone(TimeZone("Denver")),
      today.plus(1day).midnight(tz).toTimeZone(TimeZone("Denver")))
  }

  Void verifySpan(Str expr, DateTime s, DateTime e)
  {
    Span x := eval(expr)
    verifyEq(x.start, s)
    verifyEq(x.end, e)
    verifyEq(x.start.tz, s.tz)
    verifyEq(x.end.tz, e.tz)
    verifyEq(eval("${expr}.start"), s)
    verifyEq(eval("${expr}.end"), e)
  }

//////////////////////////////////////////////////////////////////////////
// Bool
//////////////////////////////////////////////////////////////////////////

  Void testBool()
  {
    verifyEval(Str<|equals(true, true)|>, true)
    verifyEval(Str<|equals(true, false)|>, false)

    verifyEval(Str<|true.format|>, "True")

    verifyEval(Str<|"false".parseBool|>, false)
    verifyEval(Str<|"xyz".parseBool(false)|>, null)
  }

//////////////////////////////////////////////////////////////////////////
// Number
//////////////////////////////////////////////////////////////////////////

  Void testNumber()
  {
    verifyEval(Str<|equals(-23, -23)|>, true)
    verifyEval(Str<|equals(23, null)|>, false)
    verifyEval(Str<|equals(null, 23)|>, false)
    verifyEval(Str<|equals(23, "foo")|>, false)
    verifyEval(Str<|equals(23, 23m)|>, false)
    verifyEval(Str<|equals(23cm, 23mm)|>, false)

    verifyEval("75.2\u00B0F", n(75.2f, "fahrenheit"))
    verifyEval("4.toStr", "4")
    verifyEval("4.toStr()", "4")
    verifyEval("(-4).toStr", "-4")
    verifyEval("(-23%).abs", n(23, "percent"))
    verifyEval("107.toHex", "6b")
    verifyEval("107.toRadix(16)", "6b")
    verifyEval("107.toRadix(16, 4)", "006b")
    verifyEval("107.toRadix(2)", "1101011")
    verifyEval("107.toRadix(2,8)", "01101011")
    verifyEval("98.core::upper", n('B'))
    verifyEval("66.lower", n('b'))
    verifyEval("107.toHex.upper", "6B")
    verifyEval("toHex(16)", "10")
    verifyEval("core::toHex(10)", "a")
    verifyEval("4.isOdd", false)
    verifyEval("4.isEven", true)
    verifyEval("6.abs", n(6))
    verifyEval("(-6).abs", n(6))
    verifyEval("107.isEven", false)
    verifyEval("104.2.isEven", true)
    verifyEval("3.isOdd", true)
    verifyEval("5.isNaN", false)
    verifyEval("posInf.isNaN", false)
    verifyEval("nan().isNaN", true)
    verifyEval("nan().toStr", "NaN")
    verifyEval("posInf()", Number(Float.posInf))
    verifyEval("negInf()", Number(Float.negInf))

    verifyEval(Str<|" "[0].isSpace|>, true)
    verifyEval(Str<|"x"[0].isSpace|>, false)
    verifyEval(Str<|"x"[0].isAlpha|>, true)
    verifyEval(Str<|"x"[0].isUpper|>, false)
    verifyEval(Str<|"x"[0].isLower|>, true)
    verifyEval(Str<|"x"[0].isDigit|>, false)
    verifyEval(Str<|"x"[0].isAlphaNum|>, true)
    verifyEval(Str<|"3"[0].isAlphaNum|>, true)
    verifyEval(Str<|"#"[0].isAlphaNum|>, false)
    verifyEval(Str<|"3"[0].isDigit|>, true)
    verifyEval(Str<|"b"[0].isDigit(10)|>, false)
    verifyEval(Str<|"b"[0].isDigit(16)|>, true)
    verifyEval(Str<|"b"[0].toChar|>, "b")

    verifyEval(Str<|1234.format("#,###")|>, "1,234")
    verifyEval(Str<|1234.0.format("#,###.0")|>, "1,234.0")

    // parseInt
    verifyEval(Str<|"-56".parseInt|>, n(-56))
    verifyEval(Str<|"ab5c".parseInt(16)|>, n(0xab5c))
    verifyEval(Str<|"xad3fc".parseInt(10, false)|>, null)

    // parseFloat
    verifyEval(Str<|"-56e-23".parseFloat|>, n(-56e-23f))
    verifyEval(Str<|"-INF".parseFloat|>, Number.negInf)
    verifyEval(Str<|"INF".parseFloat|>, Number.posInf)
    verifyEval(Str<|"xyz".parseFloat(false)|>, null)
    verifyEval(Str<|120min.format|>, "2hr")
    verifyEval(Str<|48hr.format|>, "2day")
    verifyEval(Str<|(-3min).format|>, "-3min")
    verifyEval(Str<|(-48hr).format|>, "-2day")
    verifyEval(Str<|(-48hr).format("0.0")|>, "-48.0h")
    verifyEval(Str<|6kilogram.format|>, "6kg")
    verifyEval(Str<|12$.format|>, "\$12.00")
    verifyEval(Str<|(-12$).format|>, "-\$12.00")
    verifyEval(Str<|12$.format("U#.#")|>, "\$12")
    verifyEval(Str<|(-12$).format("U#.#;(#)")|>, "(\$12)")

    // parseNumber
    verifyEval(Str<|"5min".parseNumber|>, n(5, "min"))
    verifyEval(Str<|"-123".parseNumber|>, n(-123))
    verifyEval(Str<|"15.2\u00b0C".parseNumber|>, n(15.2f, "celsius"))
    verifyEval(Str<|"1_000kWh/m\u00b2".parseNumber|>, n(1000, "kilowatt_hours_per_square_meter"))
    verifyEval(Str<|"33%".parseNumber|>, n(33, "percent"))
    verifyEval(Str<|"xyz".parseNumber(false)|>, null)
    verifyEval(Str<|"".parseNumber(false)|>, null)
    verifyEval(Str<|"3,0".parseNumber(false)|>, null)
    verifyEval(Str<|"INF".parseNumber|>, Number.posInf)
    verifyEval(Str<|"-INF".parseNumber|>, Number.negInf)
    verifyEval(Str<|"NaN".parseNumber|>, Number.nan)

    // number ranges
    verifyEval(Str<|(10..20).contains(9)|>, false)
    verifyEval(Str<|(10..20).contains(10)|>, true)
    verifyEval(Str<|(10..20).contains(20)|>, true)
    verifyEval(Str<|(10..20).contains(21)|>, false)
    verifyEval(Str<|not (10..20).contains(21)|>, true)

    // clamp
    verifyEval(Str<|clamp(3, 0, 10)|>,  n(3))
    verifyEval(Str<|clamp(-3, 0, 10)|>, n(0))
    verifyEval(Str<|clamp(13, 0, 10)|>, n(10))
    verifyEval(Str<|clamp(3ft, 0ft, 10ft)|>, n(3, "ft"))
    verifyEval(Str<|clamp(-3ft, 0ft, 10ft)|>, n(0, "ft"))
    verifyEval(Str<|clamp(-3ft, 0, 10)|>, n(0, "ft"))
    verifyEval(Str<|clamp(34ft, 0, 10)|>, n(10, "ft"))
    verifyEvalErr(Str<|clamp(65min, 1hr, 100min)|>, UnitErr#)
    verifyEvalErr(Str<|clamp(17min, 0min, 2hr)|>, UnitErr#)

    // times
    verifyBlock("x: []; 3.times(i => x = x.add(i)); x", Obj?[n(0), n(1), n(2)])
  }

//////////////////////////////////////////////////////////////////////////
// Units
//////////////////////////////////////////////////////////////////////////

  Void testUnits()
  {
    // isMetric
    oldLocale := Locale.cur
    try
    {
      Locale.setCur(Locale("en-US"))
      verifyEval("isMetric(null)", false)

      // default is metric
      Locale.setCur(Locale("en-UK"))
      verifyEval("isMetric(null)", true)
      verifyEval("isMetric({})", true)
      verifyEval("""isMetric({geoCountry:"US"})""", false)
      verifyEval("""isMetric({geoCountry:"TW"})""", true)
      verifyEval("""isMetric(4)""", true)
      verifyEval("""isMetric(4°F)""", false)
      verifyEval("""isMetric(4Δ°F)""", false)
      verifyEval("""isMetric(4°C)""", true)
      verifyEval("""isMetric(4Δ°C)""", true)
      verifyEval("""isMetric({unit:"°F"})""", false)
      verifyEval("""isMetric({unit:"fahrenheit"})""", false)
      verifyEval("""isMetric({unit:"°C"})""", true)
      verifyEval("""isMetric({unit:"celsius"})""", true)

      // default is US
      Locale.setCur(Locale("en-US"))
      verifyEval("isMetric({})", false)
      verifyEval("""isMetric({geoCountry:"US"})""", false)
      verifyEval("""isMetric({geoCountry:"TW"})""", true)
      verifyEval("""isMetric(4)""", false)
      verifyEval("""isMetric(4°F)""", false)
      verifyEval("""isMetric(4Δ°F)""", false)
      verifyEval("""isMetric(4°C)""", true)
      verifyEval("""isMetric(4Δ°C)""", true)
      verifyEval("""isMetric({unit:"°F"})""", false)
      verifyEval("""isMetric({unit:"fahrenheit"})""", false)
      verifyEval("""isMetric({unit:"°C"})""", true)
      verifyEval("""isMetric({unit:"celsius"})""", true)
    }
    finally
    {
      Locale.setCur(oldLocale)
    }

    // unit
    verifyEval("unit(null)", null)
    verifyEval("unit(40)", null)
    verifyEval("unit(40ft)", "ft")
    verifyEval("12.4\u00B0F.unit","\u00B0F")

    // unitsEq
    verifyEval("unitsEq(4, 5)", true)
    verifyEval("unitsEq(4km, 5km)", true)
    verifyEval("unitsEq(4km, 5m)", false)
    verifyEval("unitsEq(4, 5m)", false)
    verifyEval("unitsEq(null, 5m)", false)
    verifyEval("unitsEq(5m, null)", false)

    // conversions
    verifyEval("123.to(1)", n(123))
    verifyEval("123.to(1ft)", n(123, "ft"))
    verifyEval("123.to(null)", n(123))
    verifyEval("123ft.to(1)", n(123))
    verifyEval("123ft.to(1m)", n(37.4904f, "m"))
    verifyEval("123ft.to(100m)", n(37.4904f, "m"))
    verifyEval("123ft.to(\"m\")", n(37.4904f, "m"))
    verifyEval("70\u00B0F.to(1\u00B0C)", n(21.111111111111143f, "celsius"))

    // as
    verifyEval("123.as(1)", n(123))
    verifyEval("123.as(1m)", n(123, "m"))
    verifyEval("123.as(\"m\")", n(123, "m"))
    verifyEval("123km.as(1)", n(123))
    verifyEval("123ft.as(1cm)", n(123, "cm"))
    verifyEval("123ft.as(\"_pulses\")", n(123, "_pulses"))

    // addition, subtraction
    verifyUnitMath(12, "+", 4, 16)
    verifyUnitMath(12, "-", 4, 8)
    verifyEval("3mph + null", null)
    verifyEval("null + 3mph", null)

    // comparison
    verifyUnitCmp(2,  "<",   4, true)
    verifyUnitCmp(12, "<",   4, false)
    verifyUnitCmp(12, "<",  12, false)
    verifyUnitCmp(12, "<=", 44, true)
    verifyUnitCmp(44, "<=", 44, true)
    verifyUnitCmp(44, "<=", 45, true)
    verifyUnitCmp(4,  ">",   4, false)
    verifyUnitCmp(4,  ">",  -4, true)
    verifyUnitCmp(4,  ">=",  4, true)
    verifyEval("null < 3mph", true)
    verifyEval("3mph <= null", false)
    verifyEval("3mph <=> 3", n(0))
    verifyEval("3mph <=> 3mph", n(0))
    verifyErr(EvalErr#) { eval("3mph <=> 3m/s") }

    verifyEval("""parseUnit("%")""", "%")
    verifyEval("""parseUnit("percent")""", "%")
    verifyEval("""parseUnit("not_found", false)""", null)
    verifyErr(EvalErr#) { eval("""parseUnit("not_found")""") }
    verifyErr(EvalErr#) { eval("""parseUnit("not_found", true)""") }
  }

  Void verifyUnitMath(Int a, Str op, Int b, Obj result)
  {
    verifyEval("${a} $op ${b}",     n(result))
    verifyEval("${a}kg $op ${b}kg", n(result, "kg"))
    verifyEval("${a} $op ${b}kg",   n(result, "kg"))
    verifyEval("${a}kg $op ${b}",   n(result, "kg"))
    verifyErr(EvalErr#) { eval("${a}kg $op ${b}lb") }
  }

  Void verifyUnitCmp(Int? a, Str op, Int? b, Bool result)
  {
    verifyEval("${a} $op ${b}",   result)
    verifyEval("${a}m $op ${b}m", result)
    verifyEval("${a} $op ${b}m",  result)
    verifyEval("${a}m $op ${b}",  result)
    verifyErr(EvalErr#) { eval("${a}m $op ${b}ft") }
  }

//////////////////////////////////////////////////////////////////////////
// Str
//////////////////////////////////////////////////////////////////////////

  Void testStr()
  {
    verifyEval(Str<|"Foo".toStr|>, "Foo")
    verifyEval(Str<|"Foo".isEmpty|>, false)
    verifyEval(Str<|"".size|>, n(0))
    verifyEval(Str<|"".isEmpty|>, true)
    verifyEval(Str<|"hello".get(1)|>, n('e'))
    verifyEval(Str<|"hello"[4]|>, n('o'))
    verifyEval(Str<|"hello"[1..3]|>, "ell")
    verifyEval(Str<|"hello"[3..-1]|>, "lo")
    verifyEval(Str<|"hello".size|>, n(5))
    verifyEval(Str<|"Hello".upper|>, "HELLO")
    verifyEval(Str<|"Hello".lower|>, "hello")
    verifyEval(Str<|"foo".capitalize|>, "Foo")
    verifyEval(Str<|"Foo".decapitalize|>, "foo")
    verifyEval(Str<|"  a b\n".trim|>, "a b")
    verifyEval(Str<|" x \n".trimStart|>, "x \n")
    verifyEval(Str<|" x \n".trimEnd|>, " x")
    verifyEval(Str<|"a b\nc".split|>, ["a", "b", "c"])
    verifyEval(Str<|"a b\nc".split(null)|>, ["a", "b", "c"])
    verifyEval(Str<|"a b\nc".split(" ")|>, ["a", "b\nc"])
    verifyEval(Str<|"a, b, c ".split(",")|>, ["a", "b", "c"])
    verifyEval(Str<|"a, b, c ".split(",", {noTrim})|>, ["a", " b", " c "])
    verifyEval(Str<|"hello world".startsWith("hell")|>, true)
    verifyEval(Str<|"hello world".endsWith("rld")|>, true)
    verifyEval(Str<|"hello world".contains("ell")|>, true)
    verifyEval(Str<|"hello world".contains("EL")|>, false)
    verifyEval(Str<|"hello world".index("o")|>, n(4))
    verifyEval(Str<|"hello world".index("o", 5)|>, n(7))
    verifyEval(Str<|"hello world".index("x")|>, null)
    verifyEval(Str<|"hello world".indexr("o")|>, n(7))
    verifyEval(Str<|"hello world".indexr("o", -5)|>, n(4))
    verifyEval(Str<|"hello world".indexr("x")|>, null)
    verifyEval(Str<|"aa a b aa".replace("aa", "x")|>, "x a b x")
    verifyEval(Str<|"abc".padr(5)|>, "abc  ")
    verifyEval(Str<|"abc".padr(5, "-")|>, "abc--")
    verifyEval(Str<|"abc".padl(4)|>, " abc")
    verifyEval(Str<|"abc".padl(7, "-")|>, "----abc")

    verifyEval(Str<|"abc".getSafe(0)|>, n('a'))
    verifyEval(Str<|"abc".getSafe(1)|>, n('b'))
    verifyEval(Str<|"abc".getSafe(2)|>, n('c'))
    verifyEval(Str<|"abc".getSafe(3)|>, null)
    verifyEval(Str<|"abc".getSafe(-1)|>, n('c'))
    verifyEval(Str<|"abc".getSafe(-2)|>, n('b'))
    verifyEval(Str<|"abc".getSafe(-3)|>, n('a'))
    verifyEval(Str<|"abc".getSafe(-4)|>, null)

    verifyEval(Str<|"abc".getSafe(0..2)|>, "abc")
    verifyEval(Str<|"abc".getSafe(0..3)|>, "abc")
    verifyEval(Str<|"abc".getSafe(2..4)|>, "c")
    verifyEval(Str<|"abc".getSafe(3..4)|>, "")
    verifyEval(Str<|"abc".getSafe(-3..-1)|>, "abc")
    verifyEval(Str<|"abc".getSafe(-4..-1)|>, "abc")
    verifyEval(Str<|"abc".getSafe(-5..-3)|>, "a")
    verifyEval(Str<|"abc".getSafe(-5..-4)|>, "")

    verifyBlock(
      """acc: []
         each("abcd") (ch) => acc = acc.add(ch)
         acc""",
         Obj?[n('a'), n('b'), n('c'), n('d')])

    verifyBlock(
      """acc: []
         each("abcd") (ch, i) => acc = acc.add(ch).add(i)
         acc""",
         Obj?[n('a'), n(0), n('b'), n(1), n('c'), n(2), n('d'), n(3)])

    verifyBlock(
      """acc: []
         r: eachWhile("abcd") (ch) => do
           acc = acc.add(ch)
           if (ch.toChar == "c") "break"
         end
         acc.add(r)""",
         Obj?[n('a'), n('b'), n('c'), "break"])

    verifyBlock(
      """acc: []
         r: eachWhile("abcd") (ch, i) => do
           acc = acc.add(ch).add(i)
           if (i == 1) "break"
         end
         acc.add(r)""",
         Obj?[n('a'), n(0), n('b'), n(1), "break"])

    verifyBlock(
      """acc: []
         r: eachWhile("abcd") (ch, i) => do
           acc = acc.add(ch).add(i)
           null
         end
         acc.add(r)""",
         Obj?[n('a'), n(0), n('b'), n(1), n('c'), n(2), n('d'), n(3), null])

    verifyEval(Str<|"abc".any(ch=>ch.isUpper)|>, false)
    verifyEval(Str<|"aBc".any(ch=>ch.isUpper)|>, true)
    verifyEval(Str<|"aBc".all(ch=>ch.isUpper)|>, false)
    verifyEval(Str<|"ABC".all(ch=>ch.isUpper)|>, true)

    verifyBlock(
      """acc: []
         r: "abc".any((ch, i) => do
           acc = acc.add(ch).add(i)
           false
         end)
         acc.add(r)""",
         Obj?[n('a'), n(0), n('b'), n(1), n('c'), n(2), false])

    verifyBlock(
      """acc: []
         r: "abc".all((ch, i) => do
           acc = acc.add(ch).add(i)
           true
         end)
         acc.add(r)""",
         Obj?[n('a'), n(0), n('b'), n(1), n('c'), n(2), true])
  }

//////////////////////////////////////////////////////////////////////////
// Uri
//////////////////////////////////////////////////////////////////////////

  Void testUri()
  {
    verifyEval(Str<|`http://sf.com/foo`.uriScheme|>, "http")
    verifyEval(Str<|`foo`.uriScheme|>, null)
    verifyEval(Str<|`http://sf.com/foo`.uriHost|>, "sf.com")
    verifyEval(Str<|`foo`.uriHost|>, null)
    verifyEval(Str<|`http://sf.com/foo`.uriPort|>, null)
    verifyEval(Str<|`http://sf.com:99/foo`.uriPort|>, n(99))
    verifyEval(Str<|`/foo/bar/baz?query`.uriPathStr|>, "/foo/bar/baz")
    verifyEval(Str<|`/foo/bar/baz?query`.uriPath|>, ["foo", "bar", "baz"])
    verifyEval(Str<|`/foo/bar/baz.txt?query`.uriName|>, "baz.txt")
    verifyEval(Str<|`/foo/bar/baz.txt?query`.uriBasename|>, "baz")
    verifyEval(Str<|`/foo/bar/baz.txt?query`.uriExt|>, "txt")
    verifyEval(Str<|`/foo/bar/baz.txt?query`.uriIsDir|>, false)
    verifyEval(Str<|`/foo/bar/?query`.uriIsDir|>, true)
    verifyEval(Str<|parseUri("http://sf.com/")|>, `http://sf.com/`)
    verifyEval(Str<|uriEncode(`foo bar`)|>, "foo%20bar")
    verifyEval(Str<|uriDecode("foo%20bar")|>, `foo bar`)
  }

//////////////////////////////////////////////////////////////////////////
// Date
//////////////////////////////////////////////////////////////////////////

  Void testDate()
  {
    verifyEval("2010-01-03 + 2day", Date("2010-01-05"))
    verifyEval("2010-01-03 - 3day", Date("2009-12-31"))
    verifyEval("2010-01-03 - 2009-12-31", n(3, "day"))
    verifyEval("2009-12-31 - 2010-01-03", n(-3, "day"))

    verifyEval("2009-10-27.toStr", "2009-10-27")
    verifyEval("2009-10-27.year", n(2009, "yr"))
    verifyEval("2009-10-27.month", n(10, "mo"))
    verifyEval("2009-10-27.day", n(27, "day"))

    verifyEval("2010-01-09.weekday", n(6, "day"))
    verifyEval("2010-01-11.weekday", n(1, "day"))
    verifyEval("2010-01-09.isWeekend", true)
    verifyEval("2010-01-09.isWeekday", false)
    verifyEval("2010-01-11.isWeekend", false)
    verifyEval("2010-01-11.isWeekday", true)

    verifyEval("date(2010, 12, 3)", Date("2010-12-03"))
    verifyEval("date(1972, 6,  7)",  Date("1972-06-07"))

    verifyEval(Str<|2010-05-07.format("D-MMM-YY")|>, "7-May-10")

    verifyEval(Str<|"2010-05-10".parseDate|>, Date(2010, Month.may, 10))
    verifyEval(Str<|"7.May.10".parseDate("D.MMM.YY")|>, Date(2010, Month.may, 7))
    verifyEval(Str<|"xyz".parseDate("D.MMM.YY", false)|>, null)

    verifyEval("numDaysInMonth()", n(Date.today.month.numDays(Date.today.year), "day"))
    verifyEval("numDaysInMonth(6)", n(30, "day"))
    verifyEval("numDaysInMonth(2013-02-13)", n(28, "day"))
    verifyEval("numDaysInMonth(2012-02-13)", n(29, "day"))

    verifyEval("startOfWeek()", n(0, "day"))
    Locale("nn").use { verifyEval("startOfWeek()", n(1, "day")) }

    verifyEval("2016-02-01.dayOfYear", n(32, "day"))
    verifyEval("dateTime(2016-02-01, 0:00).dayOfYear", n(32, "day"))
    verifyEval("2016-02-01.weekOfYear", n(6, "day"))
    verifyEval("2016-02-01.weekOfYear(6)", n(5, "day"))
    verifyEval("dateTime(2016-02-01, 0:00).weekOfYear", n(6, "day"))

    verifyEval("isLeapYear(2019)", false)
    verifyEval("isLeapYear(2020)", true)

    verifyEval("""dateTime(2014-03-09, 00:00, "New_York").dst""", false)
    verifyEval("""dateTime(2014-03-09, 04:00, "New_York").dst""", true)
    verifyEval("""dateTime(2014-11-02, 00:00, "New_York").dst""", true)
    verifyEval("""dateTime(2014-11-02, 04:00, "New_York").dst""", false)
    verifyEval("""dateTime(2014-03-08, 04:00, "New_York").hoursInDay""", n(24))
    verifyEval("""dateTime(2014-03-09, 04:00, "New_York").hoursInDay""", n(23))
    verifyEval("""dateTime(2014-11-02, 04:00, "New_York").hoursInDay""", n(25))
  }

//////////////////////////////////////////////////////////////////////////
// Time
//////////////////////////////////////////////////////////////////////////

  Void testTime()
  {
    verifyEval("(5:45).toStr", "05:45:00")
    verifyEval("3:45.hour", n(3, "h"))
    verifyEval("15:45.hour", n(15, "h"))
    verifyEval("15:45.minute", n(45, "min"))
    verifyEval("15:45.second", n(0, "s"))
    verifyEval("15:45:07.second", n(7, "s"))

    verifyEval("15:45 + 30min", Time("16:15:00"))
    verifyEval("15:45 - 60min", Time("14:45:00"))
    verifyEval("23:45 + 75min", Time("01:00:00"))
    verifyEval("00:00 - 60min", Time("23:00:00"))

    verifyEval("time(2, 30)", Time("02:30:00"))
    verifyEval("time(2, 30, 55)", Time("02:30:55"))
    verifyEval("time(23, 0, 51.2)", Time("23:00:51"))

    verifyEval(Str<|18:03:45.format("k:mmAA")|>, "6:03PM")

    verifyEval(Str<|"03:45:07".parseTime|>, Time(3, 45, 7))
    verifyEval(Str<|"4:20pm".parseTime("k:mma")|>, Time(16, 20))
    verifyEval(Str<|"xyz".parseTime("k:mma", false)|>, null)
  }

//////////////////////////////////////////////////////////////////////////
// DateTime
//////////////////////////////////////////////////////////////////////////

  Void testDateTime()
  {
    verifyEval("""core::dateTime(2010-01-03, 12:00, "New_York") + 13hr""", DateTime("2010-01-04T01:00:00-05:00 New_York"))
    verifyEval("""core::dateTime(2010-01-03, 12:00, "New_York") - 13hr""", DateTime("2010-01-02T23:00:00-05:00 New_York"))
    verifyEval("""core::dateTime(2010-01-03, 12:00, "New_York") - core::dateTime(2010-01-03, 14:00, "New_York")""", n(-2, "h"))
    verifyEval("""dateTime(2009-10-27, 09:30:21, "New_York").date""",  Date(2009, Month.oct, 27))
    verifyEval("""dateTime(2009-10-27, 09:30:21, "New_York").time""",  Time(9, 30, 21))
    verifyEval("""dateTime(2009-10-27, 09:30:21, "New_York").year""",  n(2009, "yr"))
    verifyEval("""dateTime(2009-10-27, 09:30:21, "New_York").month""", n(10, "mo"))
    verifyEval("""dateTime(2009-10-27, 09:30:21, "New_York").day""",   n(27, "day"))
    verifyEval("""dateTime(2009-10-27, 19:30:21, "New_York").hour""",  n(19, "h"))
    verifyEval("""dateTime(2009-10-27, 09:30:21, "New_York").minute""", n(30, "min"))
    verifyEval("""dateTime(2009-10-27, 09:30:21, "New_York").second""", n(21, "s"))
    verifyEval("""dateTime(2009-10-27, 09:30:21, "New_York").weekday""", n(2, "day"))
    verifyEval("""dateTime(2009-10-27, 09:30:21, "New_York").tz""",    "New_York")
    verifyEval("""dateTime(2010-12-06, 12:30:00, "New_York").toTimeZone("Chicago")""", DateTime("2010-12-06T11:30:00-06:00 Chicago"))

    verifyEval(Str<|dateTime(2009-10-07, 16:30:21, "New_York").format("k:mma D-MMM-YY")|>, "4:30p 7-Oct-09")

    verifyEval(Str<|"2010-05-10T17:55:48.378-04:00 New_York".parseDateTime|>, DateTime("2010-05-10T17:55:48.378-04:00 New_York"))
    verifyEval(Str<|"10-May-10 5:56p".parseDateTime("D-MMM-YY k:mma", "New_York")|>, DateTime("2010-05-10T17:56:00-04:00 New_York"))
    verifyEval(Str<|"xyz".parseDateTime("D-MMM-YY k:mma", "New_York", false)|>, null)

    verifyEval("""1399286000000.fromJavaMillis("New_York").toStr""", "2014-05-05T06:33:20-04:00 New_York")
    verifyEval("""toJavaMillis("2014-05-05T06:33:20-04:00 New_York".parseDateTime)""", n(1399286000000, "ms"))
    verifyEval("""(-172800000).fromJavaMillis("UTC").toStr""","1969-12-30T00:00:00Z UTC")

    // now ticks
    Number ticks := eval("nowTicks()")
    verify(ticks.toInt - DateTime.nowTicks < 50ms.ticks)

    // verify accuracy to the microsecond range
    dt := DateTime("2030-12-31T23:45:00Z UTC").ticks + 123_000
    num := n(dt, "ns")
    diff := (num.toInt - dt).abs
    verify((num.toInt - dt).abs < 100)
  }

//////////////////////////////////////////////////////////////////////////
// Ref
//////////////////////////////////////////////////////////////////////////

  Void testRef()
  {
    verifyEval(Str<|equals(@a, @a)|>, true)
    verifyEval(Str<|equals(@a, @b)|>, false)

    ref := verifyEval("""parseRef("a.b.c")""", Ref("a.b.c"))
    verifyRefEq(ref, Ref("a.b.c", null))

    ref = verifyEval("""parseRef("a.b.c", "A B C")""", Ref("a.b.c", "A B C"))
    verifyRefEq(ref, Ref("a.b.c", "A B C"))

    ref = verifyEval("""parseRef("a.b.c", "A B C", true)""", Ref("a.b.c", "A B C"))
    verifyRefEq(ref, Ref("a.b.c", "A B C"))

    ref = verifyEval("""parseRef("@xyx-123")""", Ref("xyx-123"))
    verifyRefEq(ref, Ref("xyx-123"))

    verifyEval("""parseRef("a/b/c", "Dis", false)""", null)
    verifyErr(EvalErr#) { eval("""parseRef("!foo")""") }
    verifyErr(EvalErr#) { eval("""parseRef("bad!", "Dis", true)""") }

    verifyEval("""parseRef("@", "x", false)""", null)
    verifyErr(EvalErr#) { eval("""parseRef("@")""") }

    // signature 3.0.13 and earlier was parseRef(val, checked)
    verifyEval("""parseRef("a/b/c", false)""", null)
    verifyErr(EvalErr#) { eval("""parseRef("")""") }
    verifyErr(EvalErr#) { eval("""parseRef("bad!", true)""") }

    verifyEq(makeContext.call("refDis", [Ref("x", "Dis!")]), "Dis!")
    verifyEval(Str<|format(@foo)|>, "foo")

    verifyEval("refProjName(@p:demo:r:xxx)", "demo")
    verifyEval("refProjName(@r:xxx, false)",  null)
    verifyErr(EvalErr#) { eval("refProjName(@r:xxx)") }
    verifyErr(EvalErr#) { eval("refProjName(@r:xxx, true)") }
  }

//////////////////////////////////////////////////////////////////////////
// Symbol
//////////////////////////////////////////////////////////////////////////

  Void testSymbol()
  {
    verifyEval("""parseSymbol("lib:his")""", Symbol("lib:his"))
    verifyEval("""parseSymbol("a/b/c", false)""", null)
    verifyErr(EvalErr#) { eval("""parseSymbol("bad one")""") }
    verifyEval(Str<|format(^foo)|>, "foo")
  }

//////////////////////////////////////////////////////////////////////////
// Coord
//////////////////////////////////////////////////////////////////////////

  Void testCoord()
  {
    verifyEval("coord(12.3,-45.6)", Coord(12.3f, -45.6f))
    verifyEval("coord(12.3,-45.6).coordLat", n(12.3f))
    verifyEval("coord(12.3,-45.6).coordLng", n(-45.6f))

    // verify washing to richmond ~153.5km
    Number dist := eval("coordDist(coord(38.881468,-77.024495), coord(37.539190,-77.433049))")
    verifyEq(dist.unit.name, "meter")
    verifyEq(dist.toFloat.floor, 153463f)
  }

//////////////////////////////////////////////////////////////////////////
// Range
//////////////////////////////////////////////////////////////////////////

  Void testRange()
  {
    verifyEval("(3..-2).start", n(3))
    verifyEval("(3..-2).end", n(-2))
    verifyEval("(3..-2).map v => v*10", Obj?[n(30), n(20), n(10), n(0), n(-10), n(-20)])

    verifyBlock(
      "acc: []
       (10..12).each x => acc = acc.add(x)
       acc",
       Obj?[n(10), n(11), n(12)])

     verifyBlock(
      "acc: []
       r:  (10..20).eachWhile x => do
         if (x == 13) return \"foo\"
         acc = acc.add(x)
         null
       end
       acc.add(r)",
       Obj?[n(10), n(11), n(12), "foo"])

  }

//////////////////////////////////////////////////////////////////////////
// List
//////////////////////////////////////////////////////////////////////////

  Void testList()
  {
    verifyEval(Str<|equals([1, 2], [1, 2])|>, true)
    verifyEval(Str<|equals(["a", "b"], "a.b".split("."))|>, true)
    verifyEval(Str<|equals([1, 2], [1])|>, false)
    verifyEval(Str<|equals([1, 2], [1, 3])|>, false)
    verifyEval(Str<|equals([1, 2], null)|>, false)
    verifyEval(Str<|equals(null, [1, 2])|>, false)

    verifyEval("null.toList", Obj?[null])
    verifyEval("3.toList", Obj?[n(3)])
    verifyEval("[1,2].toList", Obj?[n(1), n(2)])

    verifyEval("[].isEmpty", true)
    verifyEval("[10, 20, 30].isEmpty", false)
    verifyEval("[10, 20, 30].size", n(3))
    verifyEval("[10, 20, 30].get(2)", n(30))
    verifyEval("[10, 20, 30][1]", n(20))
    verifyEval("[0, 1, 2, 3][1..2]", Obj?[n(1), n(2)])
    verifyEval("[0, 1, 2, 3][2..-1]", Obj?[n(2), n(3)])
    verifyEval("""["if", "x", "foo", "boat"].sort""", Obj?["boat", "foo", "if", "x"])
    verifyEval("""["if", "x", "foo", "boat"].sort((a,b)=>a.size<=>b.size)""", Obj?["x", "if", "foo", "boat"])
    verifyEval("""["if", "x", "foo", "boat"].sortr""", Obj?["x", "if", "foo", "boat"])
    verifyEval("""["if", "x", "foo", "boat"].sortr((a,b)=>a.size<=>b.size)""", Obj?["boat", "foo", "if", "x"])
    verifyEval("[].any(x=>x.isOdd)", false)
    verifyEval("[].all(x=>x.isOdd)", true)
    verifyEval("[1, 3, 6].any(x=>x.isOdd)", true)
    verifyEval("[1, 3, 6].all(x=>x.isOdd)", false)
    verifyEval("[1, 2, 3].map(x=>x+100)", Obj?[n(101),n(102),n(103)])
    verifyEval("[1, 2, 3].map(toHex)", Obj?["1", "2", "3"])
    verifyEval("[4m, 5m, 6m].map((x,i)=>x+i)", Obj?[n(4, "m"), n(6, "m"), n(8, "m")])
    verifyEval("[1, 2, 3].flatMap x=> [x, x+10]", Obj?[n(1), n(11), n(2), n(12), n(3), n(13)])
    verifyEval("[10, 20, 30].flatMap()(x,i) => [x, i]", Obj?[n(10), n(0), n(20), n(1), n(30), n(2)])
    verifyEval("[1, 2, 3, 4].find(x => x == 3)", n(3))
    verifyEval("[1, 2, 3, 4].find(x => x == 7)", null)
    verifyEval("[1, 2, 3, 4].find((x,i) => i == 3)", n(4))
    verifyEval("[1, 2, 3, 4].findAll(x=>x.isOdd)", Obj?[n(1),n(3)])
    verifyEval("[1, 3, 5, 7].findAll((x,i)=>i.isOdd)", Obj?[n(3),n(7)])
    verifyEval("[10, 20, 30].contains(20)", true)
    verifyEval("[10, 20, 30].contains(21)", false)
    verifyEval("[10, 20, null].contains(null)", true)
    verifyEval("[1, 2, 3, 2, 3].index(2)", n(1))
    verifyEval("[1, 2, 3, 2, 3].index(2, 2)", n(3))
    verifyEval("[1, 2, 3, 2, 3].index(99)", null)
    verifyEval("[1, 2, 3, 2, 3].indexr(2)", n(3))
    verifyEval("[1, 2, 3, 2, 3].indexr(2,-3)", n(1))
    verifyEval("[1, 2, 3, 2, 3].indexr(99)", null)
    verifyEval("[2, 3].first", n(2))
    verifyEval("[2, 3].last", n(3))
    verifyEval("[].first", null)
    verifyEval("[0,1,2].concat", "012")
    verifyEval("[0,1,2].concat(\",\")", "0,1,2")
    verifyEval("[].add(4)", Obj?[n(4)])
    verifyEval("[].add(null)", Obj?[null])
    verifyEval("[null].add(1)", Obj?[null, n(1)])
    verifyEval("[1,2,3].add(null)", Obj?[n(1), n(2), n(3), null])
    verifyEval("[1].add(2)", Obj?[n(1), n(2)])
    verifyEval("[].addAll([null])", Obj?[null])
    verifyEval("[1].addAll([null, 2, 3])", Obj?[n(1), null, n(2), n(3)])
    verifyEval("[1].addAll([2, 3])", Obj?[n(1), n(2), n(3)])
    verifyEval("[1, 2, 3].set(1, 99)", Obj?[n(1), n(99), n(3)])
    verifyEval("[1, 2].insert(0, 99)", Obj?[n(99), n(1), n(2)])
    verifyEval("[].insert(0, null)", Obj?[null])
    verifyEval("[1, 2].insert(1, null)", Obj?[n(1), null, n(2)])
    verifyEval("[].insertAll(0, [null, 1])", Obj?[null, n(1)])
    verifyEval("[1, 2].insertAll(0, [null, 1])", Obj?[null, n(1), n(1), n(2)])
    verifyEval("[1, 2].insertAll(1, [8, 9])", Obj?[n(1), n(8), n(9), n(2)])
    verifyEval("[10, 20, 30].remove(-1)", Obj?[n(10), n(20)])
    verifyEval("[1, 2, 2, 3, 1, `foo`].unique", Obj?[n(1), n(2), n(3), `foo`])
    verifyEval("{foo}.toGrid.colNames.set(0, 123)", Obj?[n(123)])  // contra-variants
    verifyEval("{foo}.toGrid.colNames.add(123)", Obj?["foo", n(123)])
    verifyEval("{foo}.toGrid.colNames.addAll([1, 2])", Obj?["foo", n(1), n(2)])
    verifyEval("{foo}.toGrid.colNames.insert(0, 123)", Obj?[n(123), "foo"])
    verifyEval("{foo}.toGrid.colNames.insertAll(0, [1, 2])", Obj?[n(1), n(2), "foo"])
    verifyEval(
       Str<|do
             x: () => do
               acc : ""
               ["a", "b", "c"].each() (v) => acc = acc + v + ","
               acc
             end
             x()
            end|>, "a,b,c,")
    verifyEval(
       Str<|do
             x: () => do
               acc : ""
               ["a", "b", "c"].each() (v, i) => acc = acc + i.toHex + ":" + v + ","
               acc
             end
             x()
            end|>, "0:a,1:b,2:c,")
    verifyEval(Str<|[2, 4, 3, 6].eachWhile((v, i) => if (v.isOdd) (v + "," + i) else null)|>, "3,2")

    verifyEval(Str<|[10,20].getSafe(1)|>, n(20))
    verifyEval(Str<|[10,20].getSafe(2)|>, null)
    verifyEval(Str<|[10,20].getSafe(-2)|>, n(10))
    verifyEval(Str<|[10,20].getSafe(1)|>, n(20))

    verifyEval(Str<|[10,20].getSafe(0..1)|>, Obj?[n(10), n(20)])
    verifyEval(Str<|[10,20].getSafe(0..2)|>, Obj?[n(10), n(20)])
    verifyEval(Str<|[10,20].getSafe(0..3)|>, Obj?[n(10), n(20)])
    verifyEval(Str<|[10,20].getSafe(1..4)|>, Obj?[n(20)])
    verifyEval(Str<|[10,20].getSafe(3..4)|>, Obj?[,])
    verifyEval(Str<|[10,20].getSafe(4..6)|>, Obj?[,])
    verifyEval(Str<|[10,20].getSafe(0..-2)|>, Obj?[n(10)])
    verifyEval(Str<|[10,20].getSafe(0..-3)|>, Obj?[,])

    verifyEval(Str<|[1, 2, [3, [4, 5]], 6].flatten|>, Obj?[n(1), n(2), n(3), n(4), n(5), n(6)])
    verifyEval(Str<|[{a:1}.toGrid, {a:2, b:3}.toGrid].flatten|>, Etc.makeMapsGrid(null, [["a":n(1)], ["a":n(2), "b":n(3)]]))
  }

//////////////////////////////////////////////////////////////////////////
// Reduce
//////////////////////////////////////////////////////////////////////////

   Void testReduce()
   {
     verifyEval("[].reduce(null, (a,v)=>a+v)", null)
     verifyEval("[].reduce(100, (a,v)=>a+v)", n(100))
     verifyEval("[3].reduce(0, (a,v)=>a+v)", n(3))
     verifyEval("[3, 2].reduce(0, (a,v)=>a+v)", n(5))
     verifyEval("[3, 2].reduce(100, (a,v)=>a+v)", n(105))
     verifyEval("[3, 2, 7].reduce(0, (a,v)=>a+v)", n(12))
     verifyEval("[3, 2, 7].reduce(10, (a,v)=>a+v)", n(22))
     verifyEval("[3, 2, 7].reduce(1, (a,v)=>a*v)", n(42))
     verifyEval("""[3, 2, 7].reduce("", (a,v,i)=>a+i+":"+v+",")""", "0:3,1:2,2:7,")

     verifyEval("[3, 2, 7].toGrid.reduce(0, (a,v)=>a+v->val)", n(12))
     verifyEval("[3, 2, 7].toGrid.reduce(0, (a,v,i)=>a+v->val*i)", n(16))

   }

//////////////////////////////////////////////////////////////////////////
// Fold
//////////////////////////////////////////////////////////////////////////

   Void testFold()
   {
     verifyFold([,], null, null, null, null)
     verifyFold([-9], -9f, -9f, -9f, -9f)
     verifyFold([-2, 2], 0f, 0f, -2f, 2f)
     verifyFold([-2f, 2f], 0f, 0f, -2f, 2f)
     verifyFold([2, 1, 3, 5, 4], 15f, 3f, 1f, 5f)

     verifyEval("[3m, 4m, 5m].fold(count)", n(3))
     verifyEval("[3m, 4m, 5m].fold(min)", n(3, "m"))
     verifyEval("[3m, 4m, 5m].fold(max)", n(5, "m"))
     verifyEval("[3m, 4m, 5m].fold(avg)", n(4, "m"))
     verifyEval("[nan(), nan(), nan()].fold(min)", Number.nan)
     verifyEval("[nan(), nan(), 1].fold(min)", Number.nan)
     verifyEval("[nan(), nan(), nan()].fold(max)", Number.nan)
     verifyEval("[nan(), nan(), 1].fold(max)", n(1))
   }

   Void verifyFold(Num[] list, Float? sum, Float? avg, Float? min, Float? max)
   {
     src := "[" + list.join(",") + "]"
     verifyEval("${src}.fold(count)", n(list.size))
     verifyEval("${src}.fold(sum)", n(sum))
     verifyEval("${src}.fold(avg)", n(avg))
     verifyEval("${src}.fold(max)", n(max))
     verifyEval("${src}.fold(min)", n(min))
     verifyEval("${src}.fold(spread)", max == null ? null : n(max - min))
     if (list.first == null) return
     v := list.first
     verifyEval("max($v, null)", n(v))
     verifyEval("max(null, $v)", n(v))
     verifyEval("min($v, null)", n(v))
     verifyEval("min(null, $v)", n(v))
   }

   Void testFoldNA()
   {
      verifyEval(Str<|format(na())|>, "NA")
     verifyEval("[1,2,null,na(),3].fold(count)", n(5))
     verifyEval("[1,2,null,na(),3].fold(sum)", NA.val)
     verifyEval("[1,2,null,na(),3].fold(min)", NA.val)
     verifyEval("[1,2,null,na(),3].fold(max)", NA.val)
     verifyEval("[1,2,null,na(),3].fold(avg)", NA.val)
     verifyEval("[1,2,null,na(),3].fold(spread)", NA.val)
   }

   Void testFoldCustom()
   {
     verifyEval(
       Str<|do
              average: (val, acc) => do
                if (val == foldStart()) return {sum:0, count:0}
                if (val == foldEnd()) return acc->sum / acc->count
                return {sum: acc->sum + val, count: acc->count + 1}
              end
              [3, 4, 1, 2, 2, 8, 1].fold(average)
            end
            |>,
            n(3))
   }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  Void testDict()
  {
    verifyEval(Str<|equals({}, {})|>, true)
    verifyEval(Str<|equals({a, b:12}, {b:12, a})|>, true)
    verifyEval(Str<|equals({a}, {b:12, a})|>, false)
    verifyEval(Str<|equals({a, b}, {a})|>, false)
    verifyEval(Str<|equals({a, b}, {b:12, a})|>, false)
    verifyEval(Str<|{a, b}.equals({b:12, a})|>, false)
    verifyEval(Str<|{a, b:2}.equals({b:2, a})|>, true)
    verifyEval(Str<|{a, b:2}.equals({b:null, a})|>, false)

    verifyEval("marker()", Marker.val)

    verifyEval(Str<|isTagName("foo_bar")|>, true)
    verifyEval(Str<|isTagName("foo bar")|>, false)
    verifyEval(Str<|toTagName("foo123")|>, "foo123")
    verifyEval(Str<|toTagName("Foo Bar 123")|>, "fooBar123")

    verifyEval("{}.isEmpty", true)
    verifyEval("{a}.isEmpty", false)

    verifyEval("{a:5}[\"a\"]", n(5))
    verifyEval("{a:5}.get(\"a\")", n(5))
    verifyEval("{a:5}.has(\"a\")", true)
    verifyEval("{a:5}.missing(\"a\")", false)
    verifyEval("{a:5}->a", n(5))
    verifyEval("{a:na()}[\"a\"]", NA.val)

    verifyEval("{b}[\"a\"]", null)
    verifyEval("{b}.get(\"a\")", null)
    verifyEval("{b}.has(\"a\")", false)
    verifyEval("{b}.missing(\"a\")", true)
    verifyEvalErr("{b}->a", UnknownNameErr#)

    verifyEval("{a:1, b:2, c:3}.names.sort", ["a", "b", "c"])
    verifyEval("{a:1, b:2, c:3}.vals.sort", Obj[n(1), n(2), n(3)])
    verifyEval("{a:1, b:2, c:3, d:null}.vals.sort", Obj[n(1), n(2), n(3)])

    verifyEval("""{}.any(v=>v.isOdd)""", false)
    verifyEval("""{}.all(v=>v.isOdd)""", true)
    verifyEval("""{a:1, b:2}.any(v=>v.isOdd)""", true)
    verifyEval("""{a:1, b:2}.all(v=>v.isOdd)""", false)
    verifyEval("""{a:1, b:2, c: na()}.any((v,n)=>n=="a")""", true)
    verifyEval("""{a:1, b:2, c: na()}.all((v,n)=>n=="a")""", false)

    verifyEval("{a:1, b:2, c:3, d: na()}.find(v=>v==9)", null)
    verifyEval("{a:1, b:2, c:3, d: na()}.find(v=>v==2)", n(2))
    verifyEval("{a:1, b:2, c:3, d: na()}.find(v=>v==na())", NA.val)
    verifyEval(Str<|{a:1, b:2, c:3}.find((v,k)=>k=="c")|>, n(3))

    verifyEval("{a:1, b:2, c:3, d: na()}.map(v=>v+100)", ["a":n(101), "b":n(102), "c":n(103), "d":NA.val])
    verifyEval("{a:1, b:2, c:3, d: na()}.map((v,k)=>k.upper)", ["a":"A", "b":"B", "c":"C", "d":"D"])

    verifyEval("{a:1, b:2, c:3}.findAll(v=>v.isOdd)", ["a":n(1), "c":n(3)])
    verifyEval("{a:1, b:2, c:3, d: na()}.findAll((v,k)=>k==\"b\")", ["b":n(2)])

    verifyEval("""{}.set("x", 2h)""", Str:Obj?["x":n(2, "h")])
    verifyEval("""{x:55}.set("x", 2h)""", Str:Obj?["x":n(2, "h")])
    verifyEval("""{}.set("m", marker())""", Str:Obj?["m":Marker.val])
    verifyEval("""{}.set("n", na())""", Str:Obj?["n":NA.val])

    verifyEval("""{x:5, y:3, z:na()}.remove("y")""", Str:Obj?["x":n(5), "z":NA.val])
    verifyEval("""{x:5, y:3}.remove("z")""", Str:Obj?["x":n(5), "y":n(3)])

    verifyEval(
       Str<|do
             x: () => do
               acc : ""
               {a: "A", b: "B"}.each() (v, k) => acc = acc + k + ":" + v + ","
               acc
             end
             x()
            end|>, "a:A,b:B,")

    verifyEval("""{x:5, y:3, z:2}.eachWhile(v=>if (v==5) "foo" else null)""", "foo")
    verifyEval("""{x:5, y:3, z:2}.eachWhile(v=>null)""", null)
    verifyEval("""{x:5, y:3, z:2}.eachWhile((v,n)=> if (v==3) n+v else null)""", "y3")

    dict := Etc.makeDict(["foo":"bar"])
    verifySame(Etc.dictMerge(dict, null), dict)
    verifySame(Etc.dictMerge(dict, [:]), dict)
    verifySame(Etc.dictMerge(dict, Etc.emptyDict), dict)
    verifyEval("""{x:3}.merge(null)""", Str:Obj?["x":n(3)])
    verifyEval("""{x:3}.merge({})""", Str:Obj?["x":n(3)])
    verifyEval("""{x:3}.merge({y,z:9})""", Str:Obj?["x":n(3), "y":Marker.val, "z":n(9)])
    verifyEval("""{x:3, y:88, z:99}.merge({y,z:9})""", Str:Obj?["x":n(3), "y":Marker.val, "z":n(9)])
    verifyEval("""{x:3, y:88, z:99}.merge({-y})""", Str:Obj?["x":n(3), "z":n(99)])

    verifyEval("""{dis:"hi"}.dis""", "hi")
    verifyEval("""relDis("Foo", "Foo Equip")""", "Equip")
    verifyEval("""relDis({dis:"Foo"}, {dis:"Foo Equip"})""", "Equip")
  }

//////////////////////////////////////////////////////////////////////////
// Grid Tests
//////////////////////////////////////////////////////////////////////////

  Void testGrid()
  {
    x := Str<|[{name:"andy", age:10, foo},
               {name:"brian", age:30, foo},
               {name:"charles", age:20, bar}
              ].toGrid.addMeta({title:"grids!"})|>

    verifyEval("""equals($x, $x)""", true)
    verifyEval("""equals($x, ${x}.addMeta({newMeta}))""", false)
    verifyEval("""equals($x, ${x}.addColMeta("age", {newMeta}))""", false)
    verifyEval("""equals([].toGrid.map(r => r), [].toGrid)""", true)
    verifyEval("""equals($x, ${x}.reorderCols(["age", "foo", "name"]))""", false)
    verifyEval("""equals($x, ${x}.removeCol("age"))""", false)
    verifyEval("""equals($x, ${x}[0..1])""", false)
    verifyEval("""equals($x, ${x}.map y => y.set("age", 999))""", false)

    verifyEval(x + """.has("foo")""", true)
    verifyEval(x + """.has("bad")""", false)
    verifyEval(x + """.missing("foo")""", false)
    verifyEval(x + """.missing("bad")""", true)

    verifyEval(x + """.meta->title""", "grids!")
    verifyEval(x + """.cols.map(c => c.name).sort""", Obj?["age", "bar", "foo", "name"])
    verifyEval(x + """.col("age").name""", "age")
    verifyEval(x + """.col("age").meta""", Etc.emptyDict)
    verifyEval(x + """.col("bad", false)""", null)
    verifyEvalErr(x + """.col("bad")""", UnknownNameErr#)
    verifyEvalErr(x + """.col("bad", true)""", UnknownNameErr#)
    verifyEval(x + """.sort("age")[0]->name""", "andy")
    verifyEval(x + """.sort("age").first->name""", "andy")
    verifyEval(x + """.sort("age").last->name""", "brian")

    // sort(col)
    Grid grid := eval(x + """.sort("age")""")
    verifyEq(grid.size, 3)
    verifyEq(grid.get(0)->name, "andy")
    verifyEq(grid.get(1)->name, "charles")
    verifyEq(grid.get(2)->name, "brian")

    // sort(f)
    grid = eval(x + """.sort((a, b) => a->name.size <=> b->name.size)""")
    verifyEq(grid.size, 3)
    verifyEq(grid.get(0)->name, "andy")
    verifyEq(grid.get(1)->name, "brian")
    verifyEq(grid.get(2)->name, "charles")

    // sortr(col)
    grid = eval(x + """.sortr("age")""")
    verifyEq(grid.size, 3)
    verifyEq(grid.get(0)->name, "brian")
    verifyEq(grid.get(1)->name, "charles")
    verifyEq(grid.get(2)->name, "andy")

    // sortr(f)
    grid = eval(x + """.sortr((a, b) => a->name.size <=> b->name.size)""")
    verifyEq(grid.size, 3)
    verifyEq(grid.get(0)->name, "charles")
    verifyEq(grid.get(1)->name, "brian")
    verifyEq(grid.get(2)->name, "andy")

    // any/all
    verifyEq(eval(x + """.any(r=>r->age <= 30)"""), true)
    verifyEq(eval(x + """.all(r=>r->age <= 30)"""), true)
    verifyEq(eval(x + """.any(r=>r->age < 30)"""), true)
    verifyEq(eval(x + """.all(r=>r->age < 30)"""), false)

    // foldCol
    verifyEq(eval(x + """.foldCol("age", sum)"""), n(60))
    verifyEq(eval(x + """.foldCol("age", max)"""), n(30))

    // find(f)
    verifyEq(eval(x + """.find(r => r->name.size.isEven)->name"""), "andy")
    verifyEq(eval(x + """.find(r => false)"""), null)
    verifyEq(eval(x + """.sort(\"age").find((r,i) => i == 1)->name"""), "charles")

    // findAll(f)
    grid = eval(x + """.findAll(r => r->name.size.isEven).sort("name")""")
    verifyEq(grid.size, 1)
    verifyEq(grid.get(0)->name, "andy")
    grid = eval(x + """.sort(\"name\").findAll((r,i) => i == 2)""")
    verifyEq(grid.size, 1)
    verifyEq(grid.get(0)->name, "charles")

    // get(range) slice
    grid = eval(x + """.sort("name").get(1..-1)""")
    verifyEq(grid.size, 2)
    verifyEq(grid.get(0)->name, "brian")
    verifyEq(grid.get(1)->name, "charles")

    // getSafe(index)
    verifyEq(eval(x + """.sort("name").getSafe(2)->name"""), "charles")
    verifyEq(eval(x + """.sort("name").getSafe(3)"""), null)
    verifyEq(eval(x + """.sort("name").getSafe(-3)->name"""), "andy")
    verifyEq(eval(x + """.sort("name").getSafe(-4)"""), null)

    // getSafe(range)
    grid = eval(x + """.sort("name").getSafe(1..10)""")
    verifyEq(grid.size, 2)
    verifyEq(grid.get(0)->name, "brian")
    verifyEq(grid.get(1)->name, "charles")
    grid = eval(x + """.sort("name").getSafe(-10..10)""")
    verifyEq(grid.size, 3)
    verifyEq(grid.get(0)->name, "andy")
    verifyEq(grid.get(1)->name, "brian")
    verifyEq(grid.get(2)->name, "charles")

    // map
    grid = eval(x + """.map(r => {name:r->name.upper, age:r->age+1}).sort("name")""")
    verifyEq(grid.size, 3)
    verifyEq(Etc.dictToMap(grid.get(0)), Str:Obj?["name":"ANDY",    "age":n(11)])
    verifyEq(Etc.dictToMap(grid.get(1)), Str:Obj?["name":"BRIAN",   "age":n(31)])
    verifyEq(Etc.dictToMap(grid.get(2)), Str:Obj?["name":"CHARLES", "age":n(21)])
    grid = eval(x + """.sort("name").map((r,i) => {foo:r->name + \"_\" + i})""")
    verifyEq(grid.size, 3)
    verifyEq(Etc.dictToMap(grid.get(0)), Str:Obj?["foo":"andy_0"])
    verifyEq(Etc.dictToMap(grid.get(1)), Str:Obj?["foo":"brian_1"])
    verifyEq(Etc.dictToMap(grid.get(2)), Str:Obj?["foo":"charles_2"])

    // flatMap
    grid = eval(x + """.flatMap(r => [{name:r->name.upper}, {age:r->age+1}])""")
    verifyEq(grid.size, 6)
    verifyDictEq(grid[0], Str:Obj?["name":"ANDY"])
    verifyDictEq(grid[1], Str:Obj?["age":n(11)])
    verifyDictEq(grid[2], Str:Obj?["name":"BRIAN"])
    verifyDictEq(grid[3], Str:Obj?["age":n(31)])
    verifyDictEq(grid[4], Str:Obj?["name":"CHARLES"])
    verifyDictEq(grid[5], Str:Obj?["age":n(21)])

    // each
    verifyEval(
        """do
             x: () => do
               acc : ""
               grid: ${x}
               grid.sort("name").each() (v) => acc = acc + v->name + ","
               acc
             end
             x()
           end""", "andy,brian,charles,")

    // eachWhile
    verifyEval(x+".eachWhile(r => if(r->age==10) r->name else null)", "andy")
    verifyEval(x+".sort(\"age\").eachWhile((r,i) => if (i==1) r->name else null)", "charles")
    verifyEval(x+".eachWhile((r,i) => null)", null)

    // addMeta
    grid = eval(x + """.addMeta({chart:"bar"})""")
    verifyEq(grid.meta->title, "grids!")
    verifyEq(grid.meta->chart, "bar")

    // setMeta
    grid = eval(x + """.setMeta({newMeta})""")
    verifyDictEq(grid.meta, ["newMeta":m])

    // addCol (string name)
    grid = eval(x + """.addCol("agex", r => r->age + 100).sort("name")""")
    verifyEq(grid.meta->title, "grids!")
    verifyEq(grid.cols[-1].name, "agex")
    verifyEq(grid.size, 3)
    verifyEq(grid.get(0)->age, n(10)); verifyEq(grid.get(0)->agex, n(110))
    verifyEq(grid.get(1)->age, n(30)); verifyEq(grid.get(1)->agex, n(130))
    verifyEq(grid.get(2)->age, n(20)); verifyEq(grid.get(2)->agex, n(120))

    // addCol meta
    grid = eval(x + """.addCol({name:"agex", dis:"AgeX", foo:33}, r => r->age + 100).sort("name")""")
    verifyEq(grid.cols[-1].name, "agex")
    verifyEq(grid.cols[-1].dis,  "AgeX")
    verifyEq(grid.cols[-1].meta->foo, n(33))
    verifyEq(grid.size, 3)
    verifyEq(grid.get(0)->age, n(10)); verifyEq(grid.get(0)->agex, n(110))
    verifyEq(grid.get(1)->age, n(30)); verifyEq(grid.get(1)->agex, n(130))
    verifyEq(grid.get(2)->age, n(20)); verifyEq(grid.get(2)->agex, n(120))

    // addColMeta
    grid = eval(x + """.addColMeta("age", {foo, bar:"baz"})""")
    verifyEq(grid.col("age").name, "age")
    verifyEq(grid.col("age").meta->foo, Marker.val)
    verifyEq(grid.col("age").meta->bar, "baz")

    // setColMeta
    grid = eval(x + """.addColMeta("age", {foo, bar:"baz"}).setColMeta("age", {newMeta})""")
    verifyEq(grid.col("age").name, "age")
    verifyDictEq(grid.col("age").meta, ["newMeta":m])

    // renameCol
    grid = eval(x + """.renameCol("age", "years").sort("name")""")
    verify(grid.missing("age"))
    verify(grid.has("years"))
    verify(grid.get(0).missing("age"))
    verify(grid.get(1).has("years"))
    verifyEq(grid.get(2)->years, n(20))

    // renameCols
    grid = eval(x + """.renameCols({age:"newAge", foo:"newFoo", notThere: "xxx"})""")
    verify(grid.missing("age"))
    verifyEq(grid.colNames, ["name", "newAge", "bar", "newFoo"])
    verifyEq(grid[0]->newAge, n(10))
    verifyEq(grid[0]->newFoo, m)

    // reorderCols (and colNames, moveTo)
    grid = eval(
      """do
          g: $x
          cols: g.colNames.moveTo("name", 0).moveTo("not there!", 1).moveTo("age", -1)
          g.reorderCols(cols)
         end""")
    verifyEq(grid.colNames, ["name", "bar", "foo", "age"])

    // removeCol
    grid = eval(x + """.removeCol("age")""")
    verify(grid.missing("age"))
    verify(grid.has("foo"))
    verify(grid.has("bar"))
    verify(grid.get(0).missing("age"))

    // removeCols
    grid = eval(x + """.removeCols(["foo", "bar"])""")
    verify(grid.has("age"))
    verify(grid.missing("foo"))
    verify(grid.missing("bar"))

    // gridRowToDict
    dict := eval(x+""".sort("name").gridRowsToDict((row, i)=>i.toStr,row=>row->name)""")
    verifyDictEq(dict, ["0":"andy", "1":"brian", "2":"charles"])

    // gridColsToDict
    dict = eval(x+""".gridColsToDict((col, i)=>i.toStr,col=>col.name)""")
    verifyDictEq(dict, ["0":"name", "1":"age", "2":"bar", "3":"foo"])

    // toGrid
    grid = eval(Str<|[{dis:"A",num:1}, {dis:"B", num:2}].toGrid|>)
    verifyEq(grid.size, 2)
    verifyEq(grid.colNames, ["dis", "num"])
    verifyEq(grid[0]->dis, "A")
    verifyEq(grid[1]->dis, "B")

    // addRow
    baseAddExpr := """${x}.sort("age").addColMeta("age", {ageCol})"""
    grid = eval("""${baseAddExpr}.addRow({name:"dan", age: 40, phone:"call me"})""")
    verifyEq(grid.size, 4)
    verifyEq(grid.meta->title, "grids!")
    verifyDictEq(grid.col("age").meta, ["ageCol": Marker.val])
    verifyEq(grid.get(0)->name, "andy")
    verifyEq(grid.get(1)->name, "charles")
    verifyEq(grid.get(2)->name, "brian")
    verifyEq(grid.get(3)->name, "dan")
    verifyEq(grid.get(3)->age, n(40))
    verifyEq(grid.get(3)->phone, "call me")

    // addRows w/ Grid
    grid = eval("""${baseAddExpr}.addRows( $baseAddExpr )""")
    verifyEq(grid.size, 6)
    verifyEq(grid.meta->title, "grids!")
    verifyDictEq(grid.col("age").meta, ["ageCol": Marker.val])
    verifyEq(grid.get(0)->name, "andy")
    verifyEq(grid.get(1)->name, "charles")
    verifyEq(grid.get(2)->name, "brian")
    verifyEq(grid.get(3)->name, "andy")
    verifyEq(grid.get(4)->name, "charles")
    verifyEq(grid.get(5)->name, "brian")
    emptyGrid := Etc.makeEmptyGrid
    verifySame(CoreLib.addRows(grid, emptyGrid), grid)
    verifySame(CoreLib.addRows(emptyGrid, Etc.makeEmptyGrid), emptyGrid)

    // colToList
    verifyEq(eval(x+""".sort("name").colToList("name")"""), Obj?["andy", "brian", "charles"])
    verifyEq(eval(x+""".sort("name").colToList("foo")"""), Obj?[Marker.val, Marker.val, null])
  }

  Void testColKinds()
  {
    g := ZincReader(
      Str<|ver:"2.0"
           a,b,c,d
           "1",1,N,["foo"]
           "2",T,M,{a:1}
           N,N,N,^symbol
           N,N,N,<<
             ver:"3.0"
             a,b
             5,6
             7,8
           >>
           |>.in).readGrid

    r := CoreLib.gridColKinds(g)

    verifyEq(r.cols.size, 3)
    verifyEq(r[0]->name, "a"); verifyEq(r[0]->kind, "Str"); verifyEq(r[0]->count, n(2))
    verifyEq(r[1]->name, "b"); verifyEq(r[1]->kind, "Number|Bool"); verifyEq(r[1]->count, n(2))
    verifyEq(r[2]->name, "c"); verifyEq(r[2]->kind, "Marker"); verifyEq(r[2]->count, n(1))
    verifyEq(r[3]->name, "d"); verifyEq(r[3]->kind, "List|Dict|Grid|Symbol"); verifyEq(r[3]->count, n(4))
  }

  Void testGridUnique()
  {
    // unique
    src :=
      Str<|[{dis:"A"},
            {dis:"B",x:1},
            {dis:"C",y:1},
            {dis:"D",x:1},
            {dis:"E",x:1,y:1},
            {dis:"F",x:2,y:2},
            ].toGrid|>
    verifyGridUnique("""${src}.unique("dis")""",       "A,B,C,D,E,F")
    verifyGridUnique("""${src}.unique("x")""",         "A,B,F")
    verifyGridUnique("""${src}.unique(["y"])""",       "A,C,F")
    verifyGridUnique("""${src}.unique(["x", "y"])""",  "A,B,C,E,F")
  }

  Void verifyGridUnique(Str axon, Str expected)
  {
    Grid grid := eval(axon)
    s := StrBuf()
    grid.each |r, i| { s.join(r.dis, ",") }
    verifyEq(s.toStr, expected)
  }

  Void testFoldCols()
  {
    x := Str<|[{name:"andy", x:10, y:100},
               {name:"brian", x:30, y:300},
               {name:"charles", x:20, y:200}
              ].toGrid|>

    Grid grid := eval(x + """.foldCols(["x", "y"], "sum", sum)""")
    verifyNull(grid.col("x", false))
    verifyNull(grid.col("y", false))
    verifyEq(grid[0]->sum, n(110))
    verifyEq(grid[1]->sum, n(330))
    verifyEq(grid[2]->sum, n(220))

    grid = eval(x + """.foldCols(c => {x, y}.has(c.name), "sum", sum)""")
    verifyNull(grid.col("x", false))
    verifyNull(grid.col("y", false))
    verifyEq(grid[0]->sum, n(110))
    verifyEq(grid[1]->sum, n(330))
    verifyEq(grid[2]->sum, n(220))
  }

//////////////////////////////////////////////////////////////////////////
// Typing
//////////////////////////////////////////////////////////////////////////

  Void testTyping()
  {
    verifyEval("debugType(null)", "null")
    verifyEval("debugType(4)",    "haystack::Number")
    verifyEval("isNull(null)", true);      verifyEval("3.isNull", false)
    verifyEval("isNonNull(null)", false);   verifyEval("3.isNonNull", true)
    verifyEval("true.isBool", true);       verifyEval("3.isBool", false)
    verifyEval("4.isNumber", true);        verifyEval("true.isNumber", false)
    verifyEval("\"foo\".isStr", true);     verifyEval("true.isStr", false)
    verifyEval("(@foo).isRef", true);      verifyEval("3.isRef", false)
    verifyEval("\"end\".isKeyword", true); verifyEval("\"foo\".isKeyword", false)
  }

//////////////////////////////////////////////////////////////////////////
// ToAxonCode
//////////////////////////////////////////////////////////////////////////

  Void testToAxonCode()
  {
    m := Marker.val
    verifyToAxonCode(null)
    verifyToAxonCode(m)
    verifyToAxonCode(true)
    verifyToAxonCode("foo\"bar")
    verifyToAxonCode(`file.txt`)
    verifyToAxonCode(n(123))
    verifyToAxonCode(n(123, "ft"))
    verifyToAxonCode(Number.nan)
    verifyToAxonCode(Number.posInf)
    verifyToAxonCode(Number.negInf)
    verifyToAxonCode(Date.today)
    verifyToAxonCode(Time.now)
    verifyToAxonCode(DateTime.now)
    verifyToAxonCode(Bin("text/html"))
    verifyToAxonCode(Coord(12f, -34f))
    verifyToAxonCode([,])
    verifyToAxonCode(["a", n(4)])
    verifyToAxonCode(Etc.emptyDict)
    verifyToAxonCode(Etc.makeDict(["a":m]))
    verifyToAxonCode(Etc.makeDict(["a":m, "b":"str"]))
    verifyToAxonCode(Etc.makeDict(["a b":m, "x y": Coord(1f, 2f), "b":[true, null, "x"]]))
    verifyToAxonCode(Span.today)
    verifyToAxonCode(Span(Date.today.minus(3day).midnight, Date.today.midnight))
    verifyErr(UnsupportedErr#) { CoreLib.toAxonCode(Etc.makeMapGrid(null, ["foo":"bar"])) }
  }

  Void verifyToAxonCode(Obj? val)
  {
    s := CoreLib.toAxonCode(val)
    // echo("### $s")
    verifyValEq(val, eval(s))
  }

//////////////////////////////////////////////////////////////////////////
// Regex
//////////////////////////////////////////////////////////////////////////

  Void testRegex()
  {
    // matches
    verifyEval(Str<|reMatches(r"\d+", "")|>, false)
    verifyEval(Str<|reMatches(r"\d+", "x")|>, false)
    verifyEval(Str<|reMatches(r"\d+", "2")|>, true)
    verifyEval(Str<|reMatches(r"\d+", "23")|>, true)
    verifyEval(Str<|reMatches(r"\d+", "23x")|>, false)

    // find
    verifyEval(Str<|reFind(r"\d+", "")|>, null)
    verifyEval(Str<|reFind(r"\d+", "x123y")|>, "123")
    verifyEval(Str<|reFind(r"\d\d\d", "34 456")|>, "456")

    // findAll
    verifyEval(Str<|reFindAll(r"-?\d+\.?\d*", "foo, 123, bar, 456.78, -9, baz")|>,
      ["123", "456.78", "-9"])
    verifyEval(Str<|reFindAll(r"-?\d+\.?\d*", "foo,  bar, baz")|>, Str[,])

    // groups
    verifyEval(Str<|reGroups(r"(Cool|Heat)-(\d+)", "xxx")|>, null)
    verifyEval(Str<|reGroups(r"(Cool|Heat)-(\d+)", "Cool")|>, null)
    verifyEval(Str<|reGroups(r"(Cool|Heat)-(\d+)", "Cool-xxx")|>, null)
    verifyEval(Str<|reGroups(r"(Cool|Heat)-(\d+)", "Cool-12")|>, Obj?["Cool-12", "Cool", "12"])
    verifyEval(Str<|reGroups(r"(Cool|Heat)-(\d+)", "||Heat-7||")|>, Obj?["Heat-7", "Heat", "7"])
  }

//////////////////////////////////////////////////////////////////////////
// Call
//////////////////////////////////////////////////////////////////////////

  Void testCall()
  {
    verifyEval(Str<|call("today")|>, Date.today)
    verifyEval(Str<|call("today", null)|>, Date.today)
    verifyEval(Str<|call("today", [])|>, Date.today)
    verifyEval(Str<|call(today)|>, Date.today)
    verifyEval(Str<|today.call|>, Date.today)

    verifyEval(Str<|call("replace", ["hi there", "hi", "hello"])|>, "hello there")
    verifyEval(Str<|call(replace, ["hi there", "hi", "hello"])|>, "hello there")

    verifyEval(Str<|do f: (a, b)=>[a,b]; call(f, [1, 2]); end|>, Obj?[n(1), n(2)])
  }

//////////////////////////////////////////////////////////////////////////
// Eval
//////////////////////////////////////////////////////////////////////////

  Void testEval()
  {
    verifyEval("""eval("3 + 4")""", n(7))
    verifyEval("""do x: eval("today"); x(); end""", Date.today)

    verifyEval("""call("today")""", Date.today)
    verifyEval("""call("today", null)""", Date.today)
    verifyEval("""call("today", [])""", Date.today)
    verifyEval("""call("today", ["ignore"])""", Date.today)

    verifyEval("""call("parseDate", ["2021-03-15"])""", Date("2021-03-15"))
    verifyEval("""call("parseDate", ["15-Mar-21", "DD-MMM-YY"])""", Date("2021-03-15"))
    verifyEval("""call(parseDate, ["2021-03-15"])""", Date("2021-03-15"))
    verifyEval("""call(parseDate(_, "DD-MMM-YY"), ["15-Mar-21"])""", Date("2021-03-15"))
  }

//////////////////////////////////////////////////////////////////////////
// SwizzleRefs
//////////////////////////////////////////////////////////////////////////

  Void testSwizzleRefs()
  {
    g := ZincReader(
      Str<|ver: "2.0" foo
           id,a,b,c,d
           @1,N,@2,@x,7
           @2,@1,@2,N,"x"
           @3,N,N,N,[@1, N, "x", @3]
           |>.in).readGrid
    g = CoreLib.swizzleRefs(g)
    r1 := g[0].id
    r2 := g[1].id
    r3 := g[2].id
    verifyDictEq(g.meta, ["foo":Marker.val])
    verifyDictEq(g[0], ["id":r1, "b": r2, "c":Ref("x"), "d":n(7)])
    verifyDictEq(g[1], ["id":r2, "a": r1, "b":r2, "d":"x"])
    verifyDictEq(g[2], ["id":r3, "d":[r1, null, "x", r3]])
  }

//////////////////////////////////////////////////////////////////////////
// Localization
//////////////////////////////////////////////////////////////////////////

  Void testLocalization()
  {
    verifyEval(Str<|localeUse("de", format(2021-03-01, "DD MMM YYYY"))|>, "01 Mär 2021")
    verifyEval(Str<|localeUse("de", parseDate("01 Mär 2021", "DD MMM YYYY"))|>, Date("2021-03-01"))
  }

//////////////////////////////////////////////////////////////////////////
// Check Syntax
//////////////////////////////////////////////////////////////////////////

  Void testCheckSyntax()
  {
    Grid g := eval("checkSyntax(\"(a, b) => a + b\")")
    verify(g.meta.missing("err"))
    verifyEq(g.size, 0)

    g = eval("checkSyntax(\"(a, b) => \\n  a # b\")")
    verifyEq(g.meta->err, Marker.val)
    verifyEq(g.size, 1)
    verifyEq(g.get(0)->line, n(2))
    verify(g.get(0).has("dis"))

    g = eval(Str<|checkSyntax(
                  """(a, b) => do
                     // foo
                     a # b
                     end""")|>)
    verifyEq(g.meta->err, Marker.val)
    verifyEq(g.size, 1)
    verifyEq(g.get(0)->line, n(3))
    verify(g.get(0).has("dis"))

    g = eval(Str<|checkSyntax(
                  """(a, b) => do
                     /* foo#
                     bar# */
                     a # b
                     end""")|>)
    verifyEq(g.meta->err, Marker.val)
    verifyEq(g.size, 1)
    verifyEq(g.get(0)->line, n(4))
    verify(g.get(0).has("dis"))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  AxonContext makeContext() { TestContext(this) }

  Obj? eval(Str s) { makeContext.eval(s) }

  Obj evalBlock(Str s)
  {
    wrapper :=
    """do
       foo: () => do
       $s
       end
       foo()
       end
       """
     //echo(wrapper)
     return eval(wrapper)
  }

  Void verifyBlock(Str src, Obj? expected)
  {
    verifyValEq(evalBlock(src), expected)
  }

  Obj? verifyEval(Str src, Obj? expected)
  {
    actual := eval(src)
    if (expected is Dict?[])
    {
      if (actual is Grid) { a := Dict?[,]; ((Grid)actual).each { a.add(it) }; actual = a }
      verifyDictsEq(actual, expected, false)
    }
    else if (expected is Str:Obj?)
    {
      verifyDictEq(actual, expected)
    }
    else if (expected is Dict)
    {
      verifyDictEq(actual, expected)
    }
    else if (expected is Grid)
    {
      verifyGridEq(actual, expected)
    }
    else
    {
      verifyEq(actual, expected)
    }
    return actual
  }

  Void verifyEvalErr(Str axon, Type? errType)
  {
    expr := Parser(Loc.eval, axon.in).parse
    scope := makeContext
    EvalErr? err := null
    try { expr.eval(scope) } catch (EvalErr e) { err = e }
    if (err == null) fail("EvalErr not thrown: $axon")
    if (errType == null)
    {
      verifyNull(err.cause)
    }
    else
    {
      if (err.cause == null) fail("EvalErr.cause is null: $axon")
      ((Test)this).verifyErr(errType) { throw err.cause }
    }
  }

}