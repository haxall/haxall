//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2009  Brian Frank  Creation
//   13 Jan 2016  Brian Frank  Repurpose from axon
//

using xeto
using haystack

**
** TokenizerTest
**
@Js
class TokenizerTest : HaystackTest
{
  Void test()
  {
    id   := HaystackToken.id
    kw   := HaystackToken.keyword
    num  := HaystackToken.num
    str  := HaystackToken.str
    ref  := HaystackToken.ref
    uri  := HaystackToken.uri
    date := HaystackToken.date
    time := HaystackToken.time
    dt   := HaystackToken.dateTime
    nl   := HaystackToken.nl
    c    := HaystackToken.comment
    dot  := HaystackToken.dot

    // empty
    verifyToks("", [,])

    // symbols
    verifyToks("!", [HaystackToken.bang, null])
    verifyToks("?", [HaystackToken.question, null])
    verifyToks("= => ==", [HaystackToken.assign, null, HaystackToken.fnArrow, null, HaystackToken.eq, null])
    verifyToks("- ->", [HaystackToken.minus, null, HaystackToken.arrow, null])

    // identifiers
    verifyToks("x", [id, "x"])
    verifyToks("fooBar", [id, "fooBar"])
    verifyToks("fooBar1999x",[id, "fooBar1999x"])
    verifyToks("foo_23", [id, "foo_23"])
    verifyToks("Foo", [id, "Foo"])
    verifyToks("_3", [id, "_3"])
    verifyToks("__90", [id, "__90"])

    // keywords
    verifyToks("x", [kw, "x"]) { it.keywords = ["x":"x"] }
    verifyToks("x", [kw, "_x_"]) { it.keywords = ["x":"_x_"] }

    // ints
    verifyToks("5", [num, n(5)])
    verifyToks("0x1234_abcd", [num, n(0x1234_abcd)])

    // floats
    verifyToks("5.0", [num, n(5f)])
    verifyToks("5.42", [num, n(5.42f)])
    verifyToks("123.2e32", [num, n(123.2e32f)])
    verifyToks("123.2e+32", [num, n(123.2e32f)])
    verifyToks("2_123.2e+32", [num, n(2_123.2e32f)])
    verifyToks("4.2e-7", [num, n(4.2e-7f)])

    // numbers with units
    verifyToks("-40ms", [num, n(-40, "ms")])
    verifyToks("1sec",[num, n(1, "s")])
    verifyToks("5hr", [num, n(5, "hr")])
    verifyToks("2.5day", [num, n(2.5f, "day")])
    verifyToks("12%", [num, n(12, "%")])
    verifyToks("987_foo", [num, n(987, "_foo")])
    verifyToks("-1.2m/s", [num, n(-1.2f, "m/s")])
    verifyToks("12kWh/ft\u00B2", [num, n(12, "kilowatt_hours_per_square_foot")])
    verifyToks("3_000.5J/kg_dry", [num, n(3_000.5f, "joules_per_kilogram_dry_air")])

    // strings
    verifyToks(Str<|""|>,  [str, ""])
    verifyToks(Str<|"x y"|>,  [str, "x y"])
    verifyToks(Str<|"x\"y"|>,  [str, "x\"y"])
    verifyToks(Str<|"_\u012f \n \t \\_ \u{1f973}"|>,  [str, "_\u012f \n \t \\_ \u{1f973}"])

    // date
    verifyToks("2009-10-04", [date, Date(2009, Month.oct, 4)])

    // time
    verifyToks("8:30", [time, Time(8, 30)])
    verifyToks("20:15", [time, Time(20, 15)])
    verifyToks("00:00", [time, Time(0, 0)])
    verifyToks("01:02:03", [time, Time(1, 2, 3)])
    verifyToks("23:59:59", [time, Time(23, 59, 59)])
    verifyToks("12:00:12.345", [time, Time("12:00:12.345")])

    // date time
    verifyToks("2016-01-13T09:51:33-05:00 New_York", [dt, DateTime("2016-01-13T09:51:33-05:00 New_York")])
    verifyToks("2016-01-13T09:51:33.353-05:00 New_York", [dt, DateTime("2016-01-13T09:51:33.353-05:00 New_York")])
    verifyToks("2010-12-18T14:11:30.924Z", [dt, DateTime("2010-12-18T14:11:30.924Z UTC")])
    verifyToks("2010-12-18T14:11:30.925Z UTC", [dt, DateTime("2010-12-18T14:11:30.925Z UTC")])
    verifyToks("2010-12-18T14:11:30.925Z London", [dt, DateTime("2010-12-18T14:11:30.925Z London")])
    verifyToks("2015-01-02T06:13:38.701-08:00 PST8PDT", [dt, DateTime("2015-01-02T06:13:38.701-08:00 PST8PDT")])
    verifyToks("2010-03-01T23:55:00.013-05:00 GMT+5", [dt, DateTime("2010-03-01T23:55:00.013-05:00 GMT+5")])
    verifyToks("2010-03-01T23:55:00.013+10:00 GMT-10", [dt, DateTime("2010-03-01T23:55:00.013+10:00 GMT-10")])
    verifyToks("2010-03-01T23:55:00.013+10:00 Port-au-Prince", [dt, DateTime("2010-03-01T23:55:00.013+10:00 Port-au-Prince")])

    // date time + dot
    verifyToks("2016-01-13T09:51:33.353-05:00 New_York.", [dt, DateTime("2016-01-13T09:51:33.353-05:00 New_York"), dot, null])
    verifyToks("2010-03-01T23:55:00.013-05:00 GMT+5.", [dt, DateTime("2010-03-01T23:55:00.013-05:00 GMT+5"), dot, null])
    verifyToks("2010-03-01T23:55:00.013+10:00 Port-au-Prince.", [dt, DateTime("2010-03-01T23:55:00.013+10:00 Port-au-Prince"), dot, null])

    // uri
    verifyToks(Str<|`http://foo/`|>,  [uri, `http://foo/`])
    verifyToks(Str<|`_ \n \\ \`_`|>,  [uri, `_ \n \\ \`_`])

    // Ref
    verifyToks("@125b780e-0684e169", [ref, Ref("125b780e-0684e169")])
    verifyToks("@demo:_:-.~", [ref, Ref("demo:_:-.~")])

    // newlines and whitespace
    verifyToks("a\n  b  \rc \r\nd\n\ne",
      [id, "a", nl, null,
       id, "b", nl, null,
       id, "c", nl, null,
       id, "d", nl, null, nl, null,
       id, "e"])

    // comments
    src := """// foo
              //   bar
               x  // baz
              """
    verifyToks(src, [c, "foo", nl, null, c, "  bar", nl, null, id, "x", c, "baz", nl, null]) { it.keepComments = true }
    verifyToks(src, [nl, null, nl, null, id, "x", nl, null])

    // errors
    verifyParseErr(Str<|"fo..|>,    "Unexpected end of str")
    verifyParseErr(Str<|`fo..|>,    "Unexpected end of uri")
    verifyParseErr(Str<|"\u345x"|>, "Invalid hex value for \\uxxxx")
    verifyParseErr(Str<|"\ua"|>,    "Invalid hex value for \\uxxxx")
    verifyParseErr(Str<|"\u234"|>,  "Invalid hex value for \\uxxxx")
    verifyParseErr("#",             "Unexpected symbol: '#' (0x23)")
    verifyParseErr("\n\n#",         "Unexpected symbol: '#' (0x23)", 3)
    verifyParseErr("4badUnit",      "Invalid unit name 'badUnit' [\"badUnit\"]")
  }

  Void verifyToks(Str src, Obj?[] toks, |HaystackTokenizer|? cb := null)
  {
    acc := Obj?[,]
    t := HaystackTokenizer(src.in)
    if (cb != null) cb(t)
    while (true)
    {
      x := t.next
      verifyEq(x, t.tok)
      if (x == HaystackToken.eof) break
      acc.add(t.tok).add(t.val)
    }
    /*
    echo("### $src")
    echo("    $toks")
    echo("    $acc")
    */
    verifyEq(acc, Obj?[,].addAll(toks))
  }

  Void verifyParseErr(Str s, Str msg, Int line := 1)
  {
    t := HaystackTokenizer(s.in)
    verifyErr(ParseErr#) { while (t.next != HaystackToken.eof) {} }
    verifyEq(t.val, msg)
    verifyEq(t.line, line)
  }

//////////////////////////////////////////////////////////////////////////
// Free Form
//////////////////////////////////////////////////////////////////////////

  Void testFreeForm()
  {
    verifyFreeForm("foo", ["foo":m])

    verifyFreeForm("a b", ["a":m, "b":m])
    verifyFreeForm(" a  b ", ["a":m, "b":m])
    verifyFreeForm("a,b", ["a":m, "b":m])
    verifyFreeForm("a , b", ["a":m, "b":m])

    verifyFreeForm("foo: hello", ["foo":"hello"])
    verifyFreeForm("foo: \"hello\"", ["foo":"hello"])
    verifyFreeForm("foo: \"\"", ["foo":""])
    verifyFreeForm("foo: `file.txt`", ["foo":`file.txt`])
    verifyFreeForm("foo: 123", ["foo":n(123)])
    verifyFreeForm("foo: 123%", ["foo":n(123, "%")])
    verifyFreeForm("foo: true", ["foo":true])
    verifyFreeForm("foo: false", ["foo":false])
    verifyFreeForm("foo: NA", ["foo":NA.val])
    verifyFreeForm("foo: @bar", ["foo":Ref("bar")])
    verifyFreeForm("foo: 2018-01-15", ["foo":Date("2018-01-15")])
    verifyFreeForm("foo: 13:30", ["foo":Time("13:30:00")])
    verifyFreeForm("foo: 2018-01-31T10:41:48-05:00 New_York", ["foo":DateTime("2018-01-31T10:41:48-05:00 New_York")])

    verifyFreeForm("foo, bar: 123 baz:2018-01-15", ["foo":m, "bar":n(123), "baz":Date("2018-01-15")])

    verifyFreeForm("bar: foo baz", ["bar":"foo", "baz":m])

    verifyFreeForm("bar: !just a string", ["bar":"!just a string"])

    verifyFreeForm("str", ["str":""])
    verifyFreeForm("area", ["area":n(0)])
    verifyFreeForm("area:\"force\"", ["area":"force"])
    verifyFreeForm("equipRef", ["equipRef":Ref.nullRef])
    verifyFreeForm("tagOn", ["tagOn":Obj?[,]])
    verifyFreeForm("area, equipRef", ["area":n(0), "equipRef":Ref.nullRef])
  }

  Void verifyFreeForm(Str s, Str:Obj? expected)
  {
    actual := FreeFormParser(defs, s).parse
    // echo("-- $s"); echo("   $actual")
    verifyDictEq(actual, expected)
  }
}

