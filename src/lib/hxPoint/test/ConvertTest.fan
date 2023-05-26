//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Aug 2013  Brian Frank  Creation
//

using haystack
using concurrent
using folio
using hx

**
** ConvertTest
**
class ConvertTest : HxTest
{
  PointLib? lib

  @HxRuntimeTest
  Void test()
  {
    this.lib = addLib("point")
    doCache
    doEnums
    doParse
    doEnumConverts
    doUnit
    doBool
    doTypeConverts
    doThermistor
    doFunc
  }

//////////////////////////////////////////////////////////////////////////
// Cache
//////////////////////////////////////////////////////////////////////////

  Void doCache()
  {
    verifySame(PointConvert("+3"), PointConvert("+3"))

    Err? e1 := null
    Err? e2 := null
    Obj? x
    try x = PointConvert("bad!#@#"); catch (Err e) e1 = e
    try x = PointConvert("bad!#@#"); catch (Err e) e2 = e
    verifyEq(e1.typeof, ParseErr#)
    verifySame(e1.cause, e2.cause)
  }

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  Void doEnums()
  {
    rt.db.commit(Diff.makeAdd(["enumMeta":Marker.val, "notMeta":"foo",
      "alpha": Str<|ver:"3.0"
                    name
                    "off"
                    "slow"
                    "fast"|>,
      "beta": Str<|ver:"3.0"
                   name,code
                   "negOne",-1
                   "seven",7
                   "five",5
                   "nine",9|>,
      "gamma": ZincReader(
               Str<|ver:"3.0"
                    name,code
                    "a",-1
                    "x",-1
                    "b",9
                    "b",10|>.in).readGrid]))

     rt.sync

     list := lib.enums.list
     verifyEq(list.size, 3)
     verifyEq(list[0].id, "alpha"); verifyEq(list[0].size, 3)
     verifyEq(list[1].id, "beta");  verifyEq(list[1].size, 4)
     verifyEq(list[2].id, "gamma"); verifyEq(list[2].size, 4)

     verifyEq(lib.enums.get("bad", false), null)
     verifyErr(UnknownNameErr#) { lib.enums.get("bad") }

     e := lib.enums.get("alpha")
     verifyEnumDef(e, "off",  0)
     verifyEnumDef(e, "slow", 1)
     verifyEnumDef(e, "fast", 2)
     verifyEnumBad(e)

     e = lib.enums.get("beta")
     verifyEnumDef(e, "negOne", -1)
     verifyEnumDef(e, "seven", 7)
     verifyEnumDef(e, "five", 5)
     verifyEnumDef(e, "nine", 9)

     verifyEnumBad(e)
     e = lib.enums.get("gamma")
     verifyEq(e.nameToCode("a"), n(-1))
     verifyEq(e.nameToCode("x"), n(-1))
     verifyEq(e.nameToCode("b"), n(9))
     verifyEq(e.codeToName(n(-1)), "a")
     verifyEq(e.codeToName(n(9)),  "b")
     verifyEq(e.codeToName(n(10)), "b")
     verifyEnumBad(e)
  }

  Void verifyEnumDef(EnumDef e, Str name, Int code)
  {
    verifyEq(e.nameToCode(name), n(code))
    verifyEq(e.codeToName(n(code)), name)
  }

  Void verifyEnumBad(EnumDef e)
  {
    verifyEq(e.nameToCode("bad", false), null)
    verifyErr(UnknownNameErr#) { e.nameToCode("bad") }

    verifyEq(e.codeToName(n(-9999), false), null)
    verifyErr(UnknownNameErr#) { e.codeToName(n(-9999)) }
  }

//////////////////////////////////////////////////////////////////////////
// Enum Converts
//////////////////////////////////////////////////////////////////////////

  Void doEnumConverts()
  {
    rec := Etc.makeDict(["enum":"x, y, z"])
    c := PointConvert("enumStrToNumber(gamma)")
    verifyEq(c.toStr, "enumStrToNumber(gamma,true)")
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, "a", n(-1))
    verifyConvert(c, rec, "x", n(-1))
    verifyConvert(c, rec, "b", n(9))
    verifyConvert(c, rec, "foobar", UnknownNameErr#)

    oldc := c
    c = PointConvert("enumStrToNumber( gamma, true)")
    verifyEq(oldc.toStr, c.toStr)
    verifyConvert(c, rec, "b", n(9))
    verifyConvert(c, rec, "foobar", UnknownNameErr#)

    c = PointConvert("enumStrToNumber(gamma, false)")
    verifyEq(c.toStr, "enumStrToNumber(gamma,false)")
    verifyConvert(c, rec, "b", n(9))
    verifyConvert(c, rec, "foobar", null)

    c = PointConvert("enumStrToNumber(gamma, false) ?: -123")
    verifyConvert(c, rec, "b", n(9))
    verifyConvert(c, rec, "foobar", n(-123))

    c = PointConvert("enumNumberToStr(gamma)")
    verifyEq(c.toStr, "enumNumberToStr(gamma,true)")
    verifyConvert(c, rec, null,  null)
    verifyConvert(c, rec, n(-1), "a")
    verifyConvert(c, rec, n(9),  "b")
    verifyConvert(c, rec, n(10), "b")
    verifyConvert(c, rec, n(99), UnknownNameErr#)

    c = PointConvert("enumNumberToStr(gamma,false)")
    verifyEq(c.toStr, "enumNumberToStr(gamma,false)")
    verifyConvert(c, rec, n(10), "b")
    verifyConvert(c, rec, n(99), null)

    c = PointConvert("enumStrToBool(alpha)")
    verifyEq(c.toStr, "enumStrToBool(alpha,true)")
    verifyConvert(c, rec, null,  null)
    verifyConvert(c, rec, "off", false)
    verifyConvert(c, rec, "slow", true)
    verifyConvert(c, rec, "fast", true)
    verifyConvert(c, rec, "bad", UnknownNameErr#)

    c = PointConvert("enumStrToBool(alpha, false)")
    verifyEq(c.toStr, "enumStrToBool(alpha,false)")
    verifyConvert(c, rec, "fast", true)
    verifyConvert(c, rec, "bad", null)

    c = PointConvert("enumBoolToStr(alpha)")
    verifyEq(c.toStr, "enumBoolToStr(alpha)")
    verifyConvert(c, rec, null,  null)
    verifyConvert(c, rec, false, "off")
    verifyConvert(c, rec, true,  "slow")

    c = PointConvert("enumBoolToStr(self)")
    verifyEq(c.toStr, "enumBoolToStr(self)")
    verifyConvert(c, rec, null,  null)
    verifyConvert(c, rec, false, "x")
    verifyConvert(c, rec, true,  "y")

    c = PointConvert("enumNumberToStr(self,false)")
    verifyEq(c.toStr, "enumNumberToStr(self,false)")
    verifyConvert(c, rec, n(0), "x")
    verifyConvert(c, rec, n(1), "y")
    verifyConvert(c, rec, n(2), "z")
    verifyConvert(c, rec, n(3), null)

    c = PointConvert("enumNumberToStr(self,false) ?: invalid")
    verifyEq(c.toStr, "enumNumberToStr(self,false) ?: invalid")
    verifyConvert(c, rec, n(0), "x")
    verifyConvert(c, rec, n(1), "y")
    verifyConvert(c, rec, n(2), "z")
    verifyConvert(c, rec, n(3), "invalid")

    c = PointConvert("enumStrToNumber(self,false)")
    verifyEq(c.toStr, "enumStrToNumber(self,false)")
    verifyConvert(c, rec, "x", n(0))
    verifyConvert(c, rec, "y", n(1))
    verifyConvert(c, rec, "z", n(2))
    verifyConvert(c, rec, "w", null)
  }

//////////////////////////////////////////////////////////////////////////
// Parse
//////////////////////////////////////////////////////////////////////////

  Void doParse()
  {
    // simple
    verifyParse("+81", 3f, 84f, AddConvert#, 81f)
    verifyParse("  +   -3  ", 5f, 2f, AddConvert#, -3f)
    verifyParse("-10", 17f, 7f, SubConvert#, 10f)
    verifyParse("- 10", 17f, 7f, SubConvert#, 10f)
    verifyParse("*5", 7f, 35f, MulConvert#, 5f)
    verifyParse("* 1.2", 5f, 6f, MulConvert#, 1.2f)
    verifyParse("/0.5", 12f, 24f, DivConvert#, 0.5f)
    verifyParse("&0xab", 0xd1.toFloat, 0x81.toFloat, AndConvert#, 0xab)
    verifyParse("&171", 0xd1.toFloat, 0x81.toFloat, AndConvert#, 0xab)
    verifyParse("|0xab", 0xd1.toFloat, 0xfb.toFloat, OrConvert#, 0xab)
    verifyParse("^ 0xab ", 0xd1.toFloat, 0x7a.toFloat, XorConvert#, 0xab)
    verifyParse("<< 8 ", 0xab.toFloat, 0xab00.toFloat, ShiftlConvert#, 8)
    verifyParse(">> 4 ", 0xab.toFloat, 0xa.toFloat, ShiftrConvert#, 4)

    // pow
    verifyParse("pow(8) ", 2f, 256f, PowConvert#)
    verifyParse("pow(-1) ", 77f, 1f/77f, PowConvert#)
    verifyParse("pow(-2) ", 16f, 1f/(16f*16f), PowConvert#)

    // min
    verifyParse("min(9) ", 8f, 8f, MinConvert#)
    verifyParse("min(9) ", 11f, 9f, MinConvert#)

    // max
    verifyParse("max(10) ", 8f, 10f, MaxConvert#)
    verifyParse("max(10) ", 12f, 12f, MaxConvert#)

    // toStr
    verifyParse("toStr()", null, "null", ToStrConvert#)
    verifyParse("toStr()", "foo", "foo", ToStrConvert#)
    verifyParse("toStr()", n(3), "3", ToStrConvert#)
    verifyParse("toStr()", true, "true", ToStrConvert#)

    // upper/lower
    verifyParse("upper()", null,     null,     UpperConvert#)
    verifyParse("upper()", "FooBar", "FOOBAR", UpperConvert#)
    verifyParse("lower()", null,     null,     LowerConvert#)
    verifyParse("lower()", "FooBar", "foobar", LowerConvert#)

    // strReplace
    verifyParse("strReplace(\$20, _)",    "Foo\$20Bar",      "Foo_Bar",         StrReplaceConvert#)
    verifyParse("strReplace('_', ' ')",   "Foo_Bar",         "Foo Bar",         StrReplaceConvert#)
    verifyParse("strReplace('_',' ')",    "Foo_Bar",         "Foo Bar",         StrReplaceConvert#)
    verifyParse("strReplace(' ', '')",    " Foo Bar ",       "FooBar",          StrReplaceConvert#)
    verifyParse("strReplace('xx', '__')", "xxFooxxBarxxBox", "__Foo__Bar__Box", StrReplaceConvert#)
    verifyParse("strReplace( xx, __ )",   "xxFooxxBarxxBox", "__Foo__Bar__Box", StrReplaceConvert#)

    // reset
    verifyParse("reset(10,20,300,400)", -8f, 300f, ResetConvert#)
    verifyParse("reset(10,20,300,400)", 10f, 300f, ResetConvert#)
    verifyParse("reset(10,20,300,400)", 12f, 320f, ResetConvert#)
    verifyParse("reset(10,20,300,400)", 19f, 390f, ResetConvert#)
    verifyParse("reset(10,20,300,400)", 21f, 400f, ResetConvert#)

    // pipline
    verifyParse("+14 * 10", 2f, 160f, PipelineConvert#)
    verifyParse("* 3 + 13 / 0.5 -2", 5f, 54f, PipelineConvert#)

    // endian
    verifyParse("u2SwapEndian()", 0xab23.toFloat, 0x23ab.toFloat, U2SwapEndianConvert#)
    verifyParse("u2SwapEndian()", 0xfedc.toFloat, 0xdcfe.toFloat, U2SwapEndianConvert#)
    verifyParse("u4SwapEndian()", 0xa0b1c2d3.toFloat, 0xd3c2b1a0.toFloat, U4SwapEndianConvert#)
    verifyParse("u4SwapEndian()", 0x0100abcd.toFloat, 0xcdab0001.toFloat, U4SwapEndianConvert#)

    // num to bool
    verifyParse("numberToBool()", n(0f), false, NumberToBoolConvert#)
    verifyParse("numberToBool()", n(1f), true, NumberToBoolConvert#)
    verifyParse("numberToBool() invert()", n(0f), true, PipelineConvert#)
    verifyParse("numberToBool() invert()", n(99f), false, PipelineConvert#)

    // num to str
    verifyParse("numberToStr(off, slow, fast)", n(0),  "off",  NumberToStrConvert#)
    verifyParse("numberToStr(off, slow, fast)", n(1),  "slow", NumberToStrConvert#)
    verifyParse("numberToStr(off, slow, fast)", n(2),  "fast", NumberToStrConvert#)
    verifyParse("numberToStr(off, slow, fast)", n(-1), null,   NumberToStrConvert#)
    verifyParse("numberToStr(off, slow, fast)", n(3),  null,   NumberToStrConvert#)
    verifyParse("numberToStr(off, slow, fast) ?: unknown", n(3),  "unknown",  PipelineConvert#)

    // str to bool
    verifyStrToBool("strToBool(off, *)",  ["off"], Str[,])
    verifyStrToBool("strToBool(off nil, *)",  ["off", "nil"], Str[,])
    verifyStrToBool("strToBool(*, on)",  Str[,], ["on"])
    verifyStrToBool("strToBool( * ,  on  run)",  Str[,], ["on","run"], "strToBool(*, on run)")
    verifyStrToBool("strToBool(a b c d, x y z)",  ["a","b","c","d"], ["x","y","z"])
    verifyStrToBool("strToBool(num0, num99)",  ["num0"], ["num99"])
    verifyStrToBool("strToBool(0, 1 2)",  ["0"], ["1", "2"])

    // str to number
    verifyParse("strToNumber()", n(123), n(123), StrToNumberConvert#)
    verifyParse("strToNumber()", "4.2", n(4.2f), StrToNumberConvert#)
    verifyParse("strToNumber()", "-99%", n(-99, "%"), StrToNumberConvert#)
    verifyParse("strToNumber(false)", "foo", null, StrToNumberConvert#)
    verifyParse("strToNumber(false) ?: 2.8", "foo", n(2.8f), PipelineConvert#)
    verifyParse("strToNumber(false) ?: -99", "foo", n(-99), PipelineConvert#)
    verifyParse("strToNumber() m => cm", "2m", n(200, "cm"), PipelineConvert#)

    // null to X
    verifyParse("?: false", true, true, ElvisConvert#)
    verifyParse("?: false", null, false, ElvisConvert#)
    verifyParse("?: true", false, false, ElvisConvert#)
    verifyParse("?: true", null, true, ElvisConvert#)
    verifyParse("?: NA", n(3), n(3), ElvisConvert#)
    verifyParse("?: NA", null, NA.val, ElvisConvert#)
    verifyParse("?: 125", n(2), n(2), ElvisConvert#)
    verifyParse("?: 125", null, n(125), ElvisConvert#)
    verifyParse("?: -123.456", null, n(-123.456f), ElvisConvert#)
    verifyParse("?: err", "ok", "ok", ElvisConvert#)
    verifyParse("?: err", null, "err", ElvisConvert#)

    // errors
    verifyEq(PointConvert("", false), null)
    verifyErr(ParseErr#) { x := PointConvert("", true) }
    verifyErr(ParseErr#) { x := PointConvert("-xx") }
    verifyErr(ParseErr#) { x := PointConvert("* foo") }
    verifyErr(ParseErr#) { x := PointConvert("/ 0") }
    verifyErr(ParseErr#) { x := PointConvert("/ 0") }  // cached err
    verifyErr(ParseErr#) { x := PointConvert("foo(") }
    verifyErr(ParseErr#) { x := PointConvert("foo(a") }
    verifyErr(ParseErr#) { x := PointConvert("foo(a b") }
    verifyErr(ParseErr#) { x := PointConvert("foo(a b, ") }
    verifyErr(ParseErr#) { x := PointConvert("foo(a b, c") }
    verifyErr(ParseErr#) { x := PointConvert("foo(a b, c d") }
  }

  Void verifyParse(Str s, Obj? in, Obj? out, Type type, Obj? x := null)
  {
    c := PointConvert.fromStr(s)
    rec := Etc.emptyDict
    verifyEq(c.typeof, type)
    if (in is Float && out is Float)
    {
      verifyConvert(c, rec, n(in), n(out))
      verifyConvert(c, rec, n(in, "%"), n(out, "%"))
    }
    else
    {
      q := c.convert(lib, rec, in)
      // echo("     $in [${in?.typeof}] ==> $out [${out?.typeof}]")
      verifyEq(q, out)
    }
    if (x != null) verifyEq(c->x, x)
    if (!s.contains("?:") && s != "toStr()") verifyConvert(c, rec, null, null)
  }

  Void verifyStrToBool(Str s, Str[] fs, Str[] ts, Str toStr := s)
  {
    c := (StrToBoolConvert)PointConvert.fromStr(s)
    // echo("### $s | falseStrs=[" + c.falseStrs.join(","){it.toCode} + "] trueStrs=[" + c.trueStrs.join(","){it.toCode} + "]")
    verifyEq(c.falseStrs, fs)
    verifyEq(c.trueStrs, ts)
    rec := Etc.emptyDict
    fs.each |x| { verifyConvert(c, rec, x, false) }
    ts.each |x| { verifyConvert(c, rec, x, true) }
    if (fs.size > 0 && ts.size > 0) verifyConvert(c, rec, "none", null)
    verifyEq(c.toStr, toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Units
//////////////////////////////////////////////////////////////////////////

  Void doUnit()
  {
    verifyUnit("°C=>°F", 0f, 32f)
    verifyUnit("°C => °F", 100f, 212f)
    verifyUnit("km => m", 2f, 2000f)
    verifyUnit("J/m²=>kWh/m²", 600000f,  0.16666667f)
    verifyUnit("J/m²  =>  kWh/m²", 600000f,  0.16666667f)

    // as
    rec := Etc.emptyDict
    verifyConvert(PointConvert("as(°F)"), rec, null, null)
    verifyConvert(PointConvert("as(°F)"), rec, n(55, "°F"), n(55, "°F"))
    verifyConvert(PointConvert("as(°C)"), rec, n(55, "°F"), n(55, "°C"))
    verifyConvert(PointConvert("as(ft)"), rec, n(55, "°F"), n(55, "ft"))

    // pipelines
    c := PointConvert("km=>m + 13")
    verifyConvert(c, rec, n(5f), n(5013f, "m"))
    c = PointConvert("+3 km=>m +13")
    verifyConvert(c, rec, n(5f), n(8013f, "m"))

    // errors
    c = PointConvert("°C => km")
    verifyErr(Err#) { c.convert(lib, rec, n(4f)) }
    verifyErr(UnitErr#) { c.convert(lib, rec, n(4f, "m")) }
    verifyErr(ParseErr#) { x := PointConvert("foo=>m") }
    verifyErr(ParseErr#) { x := PointConvert("m=>foo") }
    verifyErr(ParseErr#) { x := PointConvert("as()") }
    verifyErr(ParseErr#) { x := PointConvert("as(foo)") }
  }

  Void verifyUnit(Str s, Float from, Float expected)
  {
    UnitConvert c := PointConvert.fromStr(s)
    rec := Etc.emptyDict
    verifyConvert(c, rec, null, null)
    Number to := c.convert(lib, rec, n(from))
    // echo("$c | $from => $to")
    verifyEq(to.unit, c.to)
    verify(expected.approx(to.toFloat))
    to = c.convert(lib, rec, n(from, c.from))
    verifyEq(to.unit, c.to)
    verify(expected.approx(to.toFloat))
  }

//////////////////////////////////////////////////////////////////////////
// Bool
//////////////////////////////////////////////////////////////////////////

  Void doBool()
  {
    c := PointConvert("invert()")
    rec := Etc.emptyDict
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, true, false)
    verifyConvert(c, rec, false, true)
  }

//////////////////////////////////////////////////////////////////////////
// Type Converts
//////////////////////////////////////////////////////////////////////////

  Void doTypeConverts()
  {
    rec := Etc.emptyDict
    c := PointConvert("strToNumber()")
    verifyEq(c.toStr, "strToNumber(true)")
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, "123", n(123))
    verifyConvert(c, rec, "1.23ft", n(1.23f, "ft"))
    verifyConvert(c, rec, "xxx", ParseErr#)

    c = PointConvert("strToNumber(false)")
    verifyEq(c.toStr, "strToNumber(false)")
    verifyConvert(c, rec, "123", n(123))
    verifyConvert(c, rec, "1.23ft", n(1.23f, "ft"))
    verifyConvert(c, rec, "xxx", null)

    c = PointConvert("hexToNumber()")
    verifyEq(c.toStr, "hexToNumber(true)")
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, "123abc", n(0x123abc))
    verifyConvert(c, rec, "xxx", ParseErr#)

    c = PointConvert("hexToNumber(false)")
    verifyEq(c.toStr, "hexToNumber(false)")
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, "ff", n(255))
    verifyConvert(c, rec, "xxx", null)

    c = PointConvert("numberToStr()")
    verifyEq(c.toStr, "numberToStr()")
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, n(123), "123")
    verifyConvert(c, rec, n(1.23f, "ft"), "1.23ft")

    c = PointConvert("numberToHex()")
    verifyEq(c.toStr, "numberToHex()")
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, n(1234), "4d2")

    c = PointConvert("numberToBool()")
    verifyEq(c.toStr, "numberToBool()")
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, n(99), true)
    verifyConvert(c, rec, n(0), false)

    c = PointConvert("boolToNumber()")
    verifyEq(c.toStr, "boolToNumber(0,1)")
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, true, n(1))
    verifyConvert(c, rec, false, n(0))
    verifyConvert(c, rec, "not bool", n(0))

    c = PointConvert("boolToNumber(-10kW, 20kW)")
    verifyEq(c.toStr, "boolToNumber(-10kW,20kW)")
    verifyConvert(c, rec, null, null)
    verifyConvert(c, rec, true, n(20, "kW"))
    verifyConvert(c, rec, false, n(-10, "kW"))
    verifyConvert(c, rec, "not bool", n(-10, "kW"))
  }

//////////////////////////////////////////////////////////////////////////
// Thermistor
//////////////////////////////////////////////////////////////////////////

  Void doThermistor()
  {
    // 5813,51
    // 5513,53
    c := PointConvert("thermistor(3k)")
    verifyThermistor(c, 5813f, 51f)
    verifyThermistor(c, 5513f, 53f)
    verifyThermistor(c, 5663f, 52f)

    // -39 -39.44 323839
    // -37 -38.33 300974
    c = PointConvert("thermistor(10k-2)")
    verifySame(c, PointConvert("thermistor(10k-2)"))
    verifyThermistor(c, 999999f, -39f)
    verifyThermistor(c, 323840f, -39f)
    verifyThermistor(c, 323839f, -39f)
    verifyThermistor(c, 318122.75f, -38.5f)
    verifyThermistor(c, 307833.5f, -37.6f)
    verifyThermistor(c, 300974f, -37f)
    verifyThermistor(c, 10000f, 77f)
    verifyThermistor(c, 9952.6f, 77.2f)
    verifyThermistor(c, 9526f, 79f)
    verifyThermistor(c, 1070f, 185f)
    verifyThermistor(c, 1061f, 185.5f)
    verifyThermistor(c, 1034f, 187f)
    verifyThermistor(c, 1032f, 187f)
    verifyThermistor(c, -99f, 187f)
  }

  Void verifyThermistor(PointConvert c, Float ohms, Float degF)
  {
    rec := Etc.emptyDict
    degC := Number.F.convertTo(degF, Number.C)
    verifyConvert(c, rec, n(ohms), n(degF, Number.F))
    rec = Etc.makeDict(["unit": "°C"])
    verifyEq(c.convert(lib, rec, n(ohms))->toLocale("#.000"), n(degC, Number.C).toLocale("#.000"))
    rec = Etc.makeDict(["unit": "celsius"])
    verifyEq(c.convert(lib, rec, n(ohms))->toLocale("#.000"), n(degC, Number.C).toLocale("#.000"))
    verifyConvert(c, rec, null, null)
  }

//////////////////////////////////////////////////////////////////////////
// Func
//////////////////////////////////////////////////////////////////////////

  Void doFunc()
  {
    pt := addRec(["dis":"Dummy point", "point":m])

    // pointConvert
    verifyFuncConvert(null, "+3", n(3), n(6))
    verifyFuncConvert(Etc.emptyDict, "*3", n(3), n(9))
    verifyFuncConvert(pt, "*3 -1", n(3), n(8))
    verifyFuncConvert(pt.id, "numberToStr()", n(3), "3")

    // enumDefs
    g := (Grid)eval("enumDefs()")
    verifyEq(g.size, 3)
    verifyDictEq(g[0], ["id":"alpha", "size":n(3)])
    verifyDictEq(g[1], ["id":"beta",  "size":n(4)])
    verifyDictEq(g[2], ["id":"gamma", "size":n(4)])

    // enumDef(name)
    g = (Grid)eval("enumDef(\"beta\")")
    verifyEq(g.size, 4)
    verifyDictEq(g[0], ["name":"negOne", "code":n(-1)])
    verifyDictEq(g[1], ["name":"seven",  "code":n(7)])
    verifyDictEq(g[2], ["name":"five",   "code":n(5)])
    verifyDictEq(g[3], ["name":"nine",   "code":n(9)])
  }

  Void verifyFuncConvert(Obj? rec, Str pattern, Obj? from, Obj? expected)
  {
    axon := "pointConvert(" + Etc.toAxon(rec) + ", " + pattern.toCode + ", " + Etc.toAxon(from) + ")"
    actual := eval(axon)
    //echo("-- $axon | $actual ?= $expected")
    verifyEq(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

   Void verifyConvert(PointConvert c, Dict rec, Obj? val, Obj? expected)
   {
     if (expected is Type)
     {
       verifyErr(expected) { c.convert(lib, rec, val) }
     }
     else
     {
       actual := c.convert(lib, rec, val)
       // echo("  :: $actual ?= $expected")
       verifyEq(actual, expected)
     }
   }
}

