//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Sep 2010  Brian Frank  Creation
//

using haystack

**
** NumberTest
**
@Js
class NumberTest : HaystackTest
{
  const Unit sec := Unit("s")
  const Unit min := Unit("min")
  const Unit hr  := Unit("h")
  const Unit meter  := Unit("m")
  const Unit km  := Unit("km")
  const Unit F   := Unit("fahrenheit")
  const Unit C   := Unit("celsius")
  const Unit dF  := Unit("fahrenheit_degrees")
  const Unit dC  := Unit("celsius_degrees")

  Void testMake()
  {
    verifySame(Number.makeInt(0), Number.makeInt(0))
    verifySame(Number.makeInt(3), Number.makeInt(3))
    verifySame(Number.makeInt(199), Number.makeInt(199))
    verifyNotSame(Number.makeInt(3), Number.makeInt(3, Unit("mm")))
    verifyNotSame(Number.makeInt(-1), Number.makeInt(-1))
    verifyNotSame(Number.makeInt(200), Number.makeInt(200))
    verifyEq(Number.makeInt(4, Unit("mm")).unit.symbol, "mm")
  }

  Void testFromStr()
  {
    verifyEq(Number.fromStr("INF"), Number.posInf)
    verifyEq(Number.fromStr("-INF"), Number.negInf)
    verifyEq(Number.fromStr("NaN"), Number.nan)
    verifyEq(Number.fromStr("100"), Number.makeInt(100))
    verifyEq(Number.fromStr("-100"), Number.makeInt(-100))
  }

  Void testNegate()
  {
    verifyEq(-n(5), n(-5))
    verifyEq(-n(-5, hr), n(5, hr))
  }

  Void testPlus()
  {
    // unit-less
    verifyEq(n(2) + n(3), n(5))
    verifyEq(n(2.5f) + n(3.5f), n(6))
    verifyEq(n(5) + n(-9), n(-4))

    // units
    verifyNotEq(n(75, meter) + n(25, meter), n(100))
    verifyEq(n(75) + n(25, meter), n(100, meter))
    verifyEq(n(75, meter) + n(25), n(100, meter))
    verifyEq(n(75, km) + n(25, km), n(100, km))
    verifyErr(UnitErr#) { x := n(75, meter) + n(25, km) }

    // temperature
    verifyEq(n(75, F) + n(25), n(100, F))
    verifyEq(n(75) + n(25, F), n(100, F))
    verifyEq(n(75, F) + n(25, F), n(100, F)) // questionable
    verifyEq(n(75, F) + n(25, dF), n(100, F))
    verifyEq(n(75, dF) + n(25, F), n(100, F))
    verifyEq(n(75, dC) + n(25, C), n(100, C))
    verifyEq(n(75, dF) + n(25, dF), n(100, dF))
    verifyErr(UnitErr#) { x := n(75, F) + n(25, dC) }
  }

  Void testMinus()
  {
    // unit-less
    verifyEq(n(2) - n(3), n(-1))
    verifyEq(n(3.5f) - n(1.5f), n(2))

    // units
    verifyNotEq(n(75, meter) - n(25, meter), n(50))
    verifyEq(n(75) - n(25, meter), n(50, meter))
    verifyEq(n(75, meter) - n(25), n(50, meter))
    verifyErr(UnitErr#) { x := n(75, meter) - n(25, km) }

    // temperature
    verifyEq(n(75, C) - n(25), n(50, C))
    verifyEq(n(75, F) - n(25), n(50, F))
    verifyEq(n(75) - n(25, C), n(50, C))
    verifyEq(n(75) - n(25, F), n(50, F))
    verifyEq(n(75, F) - n(25, F), n(50, dF))
    verifyEq(n(75, C) - n(25, C), n(50, dC))
    verifyEq(n(75, F) - n(25, dF), n(50, F))
    verifyEq(n(75, C) - n(25, dC), n(50, C))
    verifyEq(n(75, dF) - n(25, dF), n(50, dF))
    verifyEq(n(75, dC) - n(25, dC), n(50, dC))
    verifyErr(UnitErr#) { x := n(75, dF) - n(25, F) }
    verifyErr(UnitErr#) { x := n(75, dC) - n(25, C) }
    verifyErr(UnitErr#) { x := n(75, dF) - n(25, C) }
    verifyErr(UnitErr#) { x := n(75, dF) - n(25, dC) }
  }

  Void testMult()
  {
    // unit-less
    verifyEq(n(2) * n(3), n(6))
    verifyEq(n(0.5f) * n(-4), n(-2))

    // units
    verifyEq(n(2, km) * n(3), n(6, km))
    verifyEq(n(2) * n(3, km), n(6, km))
    verifyEq(n(2, "m") * n(3, "m"), n(6, "m\u00b2"))

    // also see testUnitDefine for unique combos
  }

  Void testDiv()
  {
    // unit-less
    verifyEq(n(8) / n(2), n(4))
    verifyEq(n(8) / n(-0.5f), n(-16))

    // units
    verifyEq(n(6, km) / n(2), n(3, km))
    verifyEq(n(15, "kW") / n(5, "ft\u00b2"), n(3, "kW/ft\u00b2"))

    // also see testUnitDefine for unique combos
  }

  Void testMod()
  {
    // unit-less
    verifyEq(n(13) % n(5), n(3))

    // units
    verifyEq(n(24, km) % n(10), n(4, km))
    verifyErr(UnitErr#) { x := n(6) % n(2, km) }
    verifyErr(UnitErr#) { x := n(6, km) % n(2, km) }
  }

  Void testDuration()
  {
    verifyEq(Number.makeDuration(3hr), n(3, "h"))
    verifyEq(Number.makeDuration(3hr, Unit("min")), n(180, "min"))
    verifyEq(Number.makeDuration(-15sec, Unit("sec")), n(-15, "s"))
    verifyEq(Number.makeDuration(6day, Unit("day")), n(6, "day"))
    verifyEq(Number.makeDuration(0.5sec, Unit("ms")), n(500, "ms"))
    verifyEq(Number.makeDuration(123ms, Unit("ms")), n(123, "ms"))
    verifyEq(Number.makeDuration(0.123ms, Unit("ns")), n(123_000, "ns"))

    verifyEq(Number.makeDuration(124ms, null), n(124, "ms"))
    verifyEq(Number.makeDuration(2.3sec, null), n(2.3f, "sec"))
    verifyEq(Number.makeDuration(3min, null), n(3, "min"))
    verifyEq(Number.makeDuration(1.5hr, null), n(1.5f, "hr"))
    verifyEq(Number.makeDuration(36hr, null), n(1.5f, "day"))

    verifyEq(n(123,  "ns").toDuration, 123ns)
    verifyEq(n(123,  "ms").toDuration, 123ms)
    verifyEq(n(123,  "µs").toDuration, 123_000ns)
    verifyEq(n(0.5f, "h").toDuration, 30min)
    verifyEq(n(123, "sec").toDuration, 123sec)
    verifyEq(n(123,   "h").toDuration, 123hr)
    verifyEq(n(123, "day").toDuration, 123day)
    verifyEq(n(3,    "mo").toDuration, 90day)

    verifyEq(n(3).toDuration(false), null)
    verifyEq(n(3, "mm").toDuration(false), null)
    verifyErr(UnitErr#) { n(-222).toDuration }
    verifyErr(UnitErr#) { n(222, "mile").toDuration(true) }
  }

  Void testBytes()
  {
    verifyBytes(5f, "byte", 5)
    verifyBytes(5f, "kB", 5*1024)
    verifyBytes(5f, "MB", 5*1024*1024)
    verifyBytes(5f, "GB", 5*1024*1024*1024)
    verifyBytes(0.5f, "MB", (0.5f*1024*1024).toInt)

    verifyBytes(5f, null, null)
    verifyBytes(5f, "%", null)
    verifyBytes(5f, "meter", null)
  }

  Void verifyBytes(Float v, Str? unit, Int? expected)
  {
    // echo("::: " + n(v, unit) + " >> " + n(v, unit).toBytes(false) + " ?= " + expected)
    if (expected != null)
    {
      verifyEq(n(v, unit).toBytes, expected)
    }
    else
    {
      verifyEq(n(v, unit).toBytes(false), null)
      verifyErr(UnitErr#) { n(v, unit).toBytes }
    }
  }

  Void testUtils()
  {
    x   := n(45)
    y   := n(-33)
    nan := Number.nan

    // abs
    verifySame(x.abs, x)
    verifyEq(y.abs, n(33))

    // min, max
    verifySame(x.max(y), x)
    verifySame(y.max(x), x)
    verifySame(x.max(nan), x)
    verifySame(nan.max(x), x)
    verifySame(nan.max(nan), nan)
    verifySame(x.min(y), y)
    verifySame(y.min(x), y)
    verifySame(x.min(nan), nan)
    verifySame(nan.min(x), nan)
    verifySame(nan.min(nan), nan)

    // upper, lower
    eLo := n('e'); eUp := n('E'); dot := n('.')
    verifyEq(eLo.upper, eUp)
    verifyEq(eUp.lower, eLo)
    verifySame(eLo.lower, eLo)
    verifySame(eUp.upper, eUp)
    verifySame(dot.lower, dot)
    verifySame(dot.upper, dot)
  }

  Void testToLocale()
  {
    verifySame(NumberFormat(null), NumberFormat(null))
    verifySame(NumberFormat("U#,###.00"), NumberFormat("U#,###.00"))

    verifyEq(n(34).toLocale, "34")
    verifyEq(n(3456).toLocale, "3,456")
    verifyEq(n(-3456789).toLocale, "-3,456,789")
    verifyEq(n(3456789, "square_meter").toLocale, "3,456,789m\u00b2")

    verifyEq(n(3456789).toLocale("###.00"), "3456789.00")
    verifyEq(n(3456789, "square_meter").toLocale("###.00"), "3456789.00m\u00b2")

    verifyEq(n(75.2f).toLocale, "75.2")
    verifyEq(n(75.2f, "celsius").toLocale, "75.2\u00b0C")
    verifyEq(n(75.2f, "celsius").toLocale("#.00"), "75.20\u00b0C")

    Locale("en").use
    {
      verifyEq(n(1234f, "\$").toLocale, "\$1,234.00")
      verifyEq(n(1234.01f, "\$").toLocale, "\$1,234.01")
      verifyEq(n(1234.1f, "\$").toLocale, "\$1,234.10")
      verifyEq(n(1234.5678f, "\$").toLocale, "\$1,234.57")
      verifyEq(n(-1234.5678f, "\$").toLocale, "-\$1,234.57")
      verifyEq(n(-1234.5678f, "\$").toLocale("###"), "-1235\$")
      verifyEq(n(-1234.5678f, "\$").toLocale("U###"), "-\$1235")
      verifyEq(n(1234.5678f, "€").toLocale, "1,234.57€")
      verifyEq(n(-1234.5678f, "€").toLocale, "-1,234.57€")
      verifyEq(n(1234.5678f, "€").toLocale("#,###.00000"), "1,234.56780€")
      verifyEq(n(1234.5678f, "£").toLocale, "£1,234.57")
    }

    Locale("es").use
    {
      verifyEq(n(1234.5678f, "€").toLocale, "1.234,57€")
      verifyEq(n(-1234.5678f, "€").toLocale, "-1.234,57€")
      verifyEq(n(1234.5678f, "€").toLocale("#,###.00000"), "1.234,56780€")
    }

    verifyEq(n(123, "£").toLocale("#.000U"), "123.000£")
    verifyEq(n(123, "£").toLocale("#.000 U"), "123.000 £")
    verifyEq(n(123, "£").toLocale("#.000 [U]"), "123.000 [£]")
    verifyEq(n(123, "£").toLocale("U #.000"), "£ 123.000")
    verifyEq(n(123, "£").toLocale("<<U>> #.000"), "<<£>> 123.000")
    verifyEq(n(-123, "£").toLocale("#.000U"), "-123.000£")
    verifyEq(n(-123, "£").toLocale("U #.000"), "-£ 123.000")
    verifyEq(n(-123, "£").toLocale("U #.000;(#)"), "(£ 123.000)")
    verifyEq(n(123, "£").toLocale("[U] #.000; (#)"), "[£] 123.000")
    verifyEq(n(-123, "£").toLocale("[U] #.000; -(#)/"), "-([£] 123.000)/")

    verifyEq(n(120, "min").toLocale, "2hr")
    verifyEq(n(60, "sec").toLocale, "1min")
    verifyEq(n(60, "sec").toLocale("0.0"), "60.0s")
    verifyEq(n(60, "sec").toLocale("0.0 (U)"), "60.0 (s)")
    verifyEq(n(40, "day").toLocale, "40day")
    verifyEq(n(2, "mo").toLocale, "2mo")
    verifyEq(n(4, "yr").toLocale, "4yr")
  }

  Void testToStr()
  {
    verifyEq(n(34, "m/s").toStr, "34m/s")
    verifyEq(n(Float.posInf, "%").toStr, "INF")
    verifyEq(n(Float.negInf, "ft²").toStr, "-INF")
    verifyEq(n(Float.nan, "h").toStr, "NaN")
  }

  Void testSerialization()
  {
    buf := StrBuf()
    buf.out.writeObj(n(123))
    verifyEq(buf.toStr.in.readObj, n(123))
    buf.clear.out.writeObj(n(200, "ft"))
    verifyEq(buf.toStr.in.readObj, n(200, "ft"))
  }

  Void testUnitDefine()
  {
    x := n(100, "BTU") / n(2, "°daysF")
    verifyUnitDefine(x, 50f, "_BTU/°daysF")

    x = n(100, "BTU") / n(2, "°daysF") / n(5, "m²")
    verifyUnitDefine(x, 10f, "_BTU/°daysF/m²")

    x = n(100, "BTU") * n(3, "%") / n(2, "°daysF") / n(5, "m²")
    verifyUnitDefine(x, 30f, "_BTU_%/°daysF/m²")

    x = n(2, "ft") * n(3, "ft") * n(4, "ft") * n(5, "%")
    verifyUnitDefine(x, 120f, "_ft³_%")
  }

  Void verifyUnitDefine(Number n, Float f, Str u)
  {
     verifyEq(n.toFloat, f)
     verifyEq(n.unit.toStr, u)
     verifySame(n.unit, Unit.fromStr(u))

     x := ZincWriter.tagsToStr(["test":n])
     tags := ZincReader(x.in).readTags
     verifyEq(tags["test"], n)
  }

}