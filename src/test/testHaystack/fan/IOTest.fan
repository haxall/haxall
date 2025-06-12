//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Jan 2016  Brian Frank  Create
//

using haystack

**
** IOTest tests the various reader/writer classes which
** provide 100% full fidelity with Haystack
**
class IOTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Singletons
//////////////////////////////////////////////////////////////////////////

  Void testSingletons()
  {
    verifyIO(null,          "N",    Str<|null|>, "null")
    verifyIO(true,          "T",    Str<|true|>, "true")
    verifyIO(false,         "F",    Str<|false|>, "false")
    verifyIO(Marker.val,    "M",    Str<|"m:"|>, Str<|{"_kind":"marker"}|>)
    verifyIO(Remove.val,    "R",    Str<|"-:"|>, Str<|{"_kind":"remove"}|>)
    verifyIO(NA.val,        "NA",   Str<|"z:"|>, Str<|{"_kind":"na"}|>)
    verifyIO(Number.nan,    "NaN",  Str<|"n:NaN"|>, Str<|{"_kind":"number", "val":"NaN"}|>)
    verifyIO(Number.posInf, "INF",  Str<|"n:INF"|>, Str<|{"_kind":"number", "val":"INF"}|>)
    verifyIO(Number.negInf, "-INF", Str<|"n:-INF"|>, Str<|{"_kind":"number", "val":"-INF"}|>)
  }

//////////////////////////////////////////////////////////////////////////
// Numbers
//////////////////////////////////////////////////////////////////////////

  Void testNumbers()
  {
    // integers
    verifyNumber(123,    "123")
    verifyNumber(-123,   "-123")
    verifyNumber(1_234,  "1_234")
    verifyNumber(-1_234, "-1_234")

    // hex
    verifyNumber(0xabcd,      "0xabcd")
    verifyNumber(0xf234_abcd, "0xf234_abcd")

    // floating points
    verifyNumber(1.2f,   "1.2")
    verifyNumber(-80.09f, "-80.09")

    // exponential
    verifyNumber(1.234E12f,   "1.234E12")
    verifyNumber(1.234E+12f,  "1.234E+12")
    verifyNumber(1.234E12f,   "1.234E12")
    verifyNumber(-1.234E+12f, "-1.234E+12")
    verifyNumber(-1.234E-12f, "-1.234E-12")
    verifyNumber(-1.234E-12f, "-1.234E-12")
  }

  private Void verifyNumber(Num num, Str s)
  {
    verifyIO(n(num), s, "\"n:$s\"")
    verifyJson(n(num), num.toStr)
    if (s.startsWith("0x")) return

    units := ["ft", "ft/s", "_foo", "ms", "day", "%", "Δ°F", "°daysC", "inH₂O", "J/kg_dry"]
    units.each |u|
    {
      verifyIO(n(num, u), "$s$u", "\"n:$s $u\"")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Str
//////////////////////////////////////////////////////////////////////////

  Void testStr()
  {
    verifyIO("",         Str<|""|>,         Str<|""|>,         Str<|""|>)
    verifyIO("!",        Str<|"!"|>,        Str<|"!"|>,        Str<|"!"|>)
    verifyIO("x y",      Str<|"x y"|>,      Str<|"x y"|>,      Str<|"x y"|>)
    verifyIO("x\"y",     Str<|"x\"y"|>,     Str<|"x\"y"|>,     Str<|"x\"y"|>)
    verifyIO("\n\t\\",   Str<|"\n\t\\"|>,   Str<|"\n\t\\"|>,   Str<|"\n\t\\"|>)
    verifyIO("\u00ab",   Str<|"\u00ab"|>,   Str<|"\u00ab"|>,   Str<|"\u00ab"|>)
    verifyIO("\u07ab",   Str<|"\u07ab"|>,   Str<|"\u07ab"|>,   Str<|"\u07ab"|>)
    verifyIO("\u5fab",   Str<|"\u5fab"|>,   Str<|"\u5fab"|>,   Str<|"\u5fab"|>)
    verifyIO("<\u5fab>", Str<|"<\u5fab>"|>, Str<|"<\u5fab>"|>, Str<|"<\u5fab>"|>)
    verifyIO("m:",       Str<|"m:"|>,       Str<|"s:m:"|>,     Str<|"m:"|>)
    verifyIO("d:foo",    Str<|"d:foo"|>,    Str<|"s:d:foo"|>,  Str<|"d:foo"|>)
    verifyIO("d:\n",    Str<|"d:\n"|>,      Str<|"s:d:\n"|>,   Str<|"d:\n"|>)
  }

//////////////////////////////////////////////////////////////////////////
// Uri
//////////////////////////////////////////////////////////////////////////

  Void testUri()
  {
    verifyIO(``,            Str<|``|>,            Str<|"u:"|>,             Str<|{"_kind":"uri", "val":""}|>)
    verifyIO(`foo.txt`,     Str<|`foo.txt`|>,     Str<|"u:foo.txt"|>,      Str<|{"_kind":"uri", "val":"foo.txt"}|>)
    verifyIO(`_ \n \\ \`_`, Str<|`_ \n \\ \`_`|>, Str<|"u:_ \n \\\\ `_"|>, Str<|{"_kind":"uri", "val":"_ \n \\\\ `_"}|>)
  }

//////////////////////////////////////////////////////////////////////////
// Ref
//////////////////////////////////////////////////////////////////////////

  Void testRef()
  {
    verifyIO(Ref("a"),           Str<|@a|>,         Str<|"r:a"|>,                   Str<|{"_kind":"ref", "val":"a"}|>)
    verifyIO(Ref("a:b"),         Str<|@a:b|>,       Str<|"r:a:b"|>,                 Str<|{"_kind":"ref", "val":"a:b"}|>)
    verifyIO(Ref("a", "A Dis"),  Str<|@a "A Dis"|>, Str<|"r:a A Dis"|>,             Str<|{"_kind":"ref", "val":"a", "dis":"A Dis"}|>)
    verifyIO(Ref("demo:_:-.~"),  Str<|@demo:_:-.~|>, Str<|"r:demo:_:-.~"|>,         Str<|{"_kind":"ref", "val":"demo:_:-.~"}|>)
    verifyIO(Ref("x:_:-.~", "Hi!"),  Str<|@x:_:-.~ "Hi!"|>, Str<|"r:x:_:-.~ Hi!"|>, Str<|{"_kind":"ref", "val":"x:_:-.~", "dis":"Hi!"}|>)
  }

//////////////////////////////////////////////////////////////////////////
// Symbol
//////////////////////////////////////////////////////////////////////////

  Void testSymbol()
  {
    verifyIO(Symbol("a"),        Str<|^a|>,        Str<|"y:a"|>)
    verifyIO(Symbol("a:b"),      Str<|^a:b|>,      Str<|"y:a:b"|>)
    verifyIO(Symbol("foo-bar"),  Str<|^foo-bar|>,  Str<|"y:foo-bar"|>)
    verifyIO(Symbol("x:y-z"),    Str<|^x:y-z|>,    Str<|"y:x:y-z"|>)
  }

//////////////////////////////////////////////////////////////////////////
// Date
//////////////////////////////////////////////////////////////////////////

  Void testDate()
  {
    verifyIO(Date(1972, Month.jun, 1),   Str<|1972-06-01|>,  Str<|"d:1972-06-01"|>)
    verifyIO(Date(2009, Month.oct, 4),   Str<|2009-10-04|>,  Str<|"d:2009-10-04"|>)
    verifyIO(Date(2018, Month.dec, 31),  Str<|2018-12-31|>,  Str<|"d:2018-12-31"|>)
  }

//////////////////////////////////////////////////////////////////////////
// Time
//////////////////////////////////////////////////////////////////////////

  Void testTime()
  {
    verifyIO(Time(8, 30),          Str<|8:30|>,         Str<|"h:8:30"|>)
    verifyIO(Time(8, 30),          Str<|08:30|>,        Str<|"h:08:30"|>)
    verifyIO(Time(20, 15),         Str<|20:15|>,        Str<|"h:20:15"|>)
    verifyIO(Time(0, 0),           Str<|00:00|>,        Str<|"h:00:00"|>)
    verifyIO(Time(0, 0),           Str<|0:00:00|>,      Str<|"h:0:00:00"|>)
    verifyIO(Time(1, 2, 3),        Str<|1:02:03|>,      Str<|"h:1:02:03"|>)
    verifyIO(Time(23, 59, 59),     Str<|23:59:59|>,     Str<|"h:23:59:59"|>)
    verifyIO(Time("12:00:12.345"), Str<|12:00:12.345|>, Str<|"h:12:00:12.345"|>)
  }

//////////////////////////////////////////////////////////////////////////
// DateTime
//////////////////////////////////////////////////////////////////////////

  Void testDateTime()
  {
    verifyDateTime("2010-12-18T14:11:30.925Z UTC")
    verifyDateTime("2010-12-18T14:11:30.925Z London")
    verifyDateTime("2010-12-18T14:11:30.924Z",
      DateTime(2010, Month.dec, 18, 14, 11, 30, 924_000_000, TimeZone.utc))

    verifyDateTime("2016-01-13T09:51:33-05:00 New_York")
    verifyDateTime("2016-01-13T09:51:33.353-05:00 New_York")
    verifyDateTime("2015-01-02T06:13:38.701-08:00 PST8PDT")
    verifyDateTime("2010-03-01T23:55:00.013-05:00 GMT+5")
    verifyDateTime("2010-03-01T23:55:00.013+10:00 GMT-10")
  }

  Void verifyDateTime(Str s, DateTime? val := null)
  {
    if (val == null) val = DateTime(s)
    verifyIO(val, s, "\"t:$s\"")
  }

//////////////////////////////////////////////////////////////////////////
// Coord
//////////////////////////////////////////////////////////////////////////

  Void testCoord()
  {
    verifyIO(Coord(12f,-34f),       "C(12,-34)",       Str<|"c:12,-34"|>)
    verifyIO(Coord(0.123f,-0.789f), "C(0.123,-0.789)", Str<|"c:0.123,-0.789"|>)
    verifyIO(Coord(84.5f,-77.45f),  "C(84.5,-77.45)",  Str<|"c:84.5,-77.45"|>)
    verifyIO(Coord(-90f,180f),      "C(-90,180)",      Str<|"c:-90,180"|>)

    verifyZincErr(Str<|C|>)
    verifyZincErr(Str<|C(|>)
    verifyZincErr(Str<|C(90|>)
    verifyZincErr(Str<|C(90,|>)
    verifyZincErr(Str<|C(90,40|>)
    verifyZincErr(Str<|C(90,40]|>)
  }

//////////////////////////////////////////////////////////////////////////
// XStr
//////////////////////////////////////////////////////////////////////////

  Void testXStr()
  {
    verifyIO(XStr("C", "foo"),  Str<|C("foo")|>, Str<|"x:C:foo"|>)
    verifyIO(XStr("T", "foo"),  Str<|T("foo")|>, Str<|"x:T:foo"|>)
    verifyIO(XStr("FooBar", "foo\nbar\"\u24ab"),  Str<|FooBar("foo\nbar\"\u24ab")|>, Str<|"x:FooBar:foo\nbar\"\u24ab"|>)

    ts := Date("2016-02-03").midnight
    verifyIO(Span(SpanMode.today),  Str<|Span("today")|>, Str<|"x:Span:today"|>)
    verifyIO(Span(ts, ts.plus(1day)), Str<|Span("2016-02-03")|>, Str<|"x:Span:2016-02-03"|>)

    verifyIO(Bin("text/plain"),  Str<|Bin("text/plain")|>, Str<|"x:Bin:text/plain"|>)

    verifyZincErr(Str<|foo("bar")|>)
    verifyZincErr(Str<|foo()|>)
    verifyZincErr(Str<|foo('bar')|>)
    verifyZincErr(Str<|foo("bar)|>)
    verifyZincErr(Str<|foo("bar"|>)
  }

//////////////////////////////////////////////////////////////////////////
// List
//////////////////////////////////////////////////////////////////////////

  Void testList()
  {
    ra := Ref("a")
    rb := Ref("b")
    rbd := Ref("b", "Beta")

    verifyIO(Obj?[,],                     Str<|[]|>,             "[]")
    verifyIO(Number[n(1)],                Str<|[1]|>,            "[1]")
    verifyIO(Number[n(1)],                Str<|[1,]|>,           "[\"n:1\"]")
    verifyIO(Number[n(1), n(2)],          Str<|[1, 2]|>,         "[1, 2]")
    verifyIO(Number[n(1), n(2), n(3)],    Str<|[1, 2, 3]|>,      """[1, "n:2", "n:3"]""")
    verifyIO(Number?[n(1), null, n(3)],   Str<|[1, N, 3]|>,      """[1, null, "n:3"]""")
    verifyIO(Number?[null, null, n(3)],   Str<|[N, N, 3]|>,      "[null,null,3]")
    verifyIO(Obj?[null],                  Str<|[N]|>,            "[ null ]")
    verifyIO(Obj?[null, null],            Str<|[N, N]|>,         "[null, null]")
    verifyIO(Str?[null, "a"],             Str<|[N, "a"]|>,       """[null, "a"]""")
    verifyIO(Ref[ra, rb],                 Str<|[@a, @b]|>,       """["r:a", "r:b"]""")
    verifyIO(Ref?[null, ra, rb],          Str<|[N, @a, @b]|>,    """[null, "r:a", "r:b"]""")
    verifyIO(Ref?[null, null, ra, rb],    Str<|[N, N, @a, @b]|>, """[null, null, "r:a", "r:b"]""")
    verifyIO(Obj?[null, ra, rb, "Beta"],  Str<|[N, @a,   @b, "Beta"]|>, """[null,"r:a","r:b","Beta"]""")
    verifyIO(Obj?[null, ra, rbd, n(123)], Str<|[N, @a, @b "Beta", 123  ,  ]|>, """[null, "r:a", "r:b Beta", "n:123"]""")
    verifyIO(Obj?["a", null, true, `u`],  Str<|["a",N,T,`u`,]|>, """["s:a", null, true, "u:u"]""")

    verifyZincErr(Str<|[|>)
    verifyZincErr(Str<|[,]|>)
    verifyZincErr(Str<|[3,|>)
    verifyZincErr(Str<|[3 3]|>)
  }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  Void testDict()
  {
    verifyIO(Etc.emptyDict,
      Str<|{}|>,
      null)

    verifyIO(Etc.makeDict(["foo":Marker.val]),
      Str<|{foo}|>,
      null)

    verifyIO(Etc.makeDict(["foo":n(123)]),
      Str<|{foo:123}|>,
      null)

    verifyIO(Etc.makeDict(["dis":"hi", "marker":Marker.val, "age":n(40)]),
      Str<|{dis:"hi" marker age:40}|>,
      null)

    verifyZincErr(Str<|{|>)
    verifyZincErr(Str<|{3|>)
    verifyZincErr(Str<|{foo|>)
    verifyZincErr(Str<|{foo 3}|>)
  }

//////////////////////////////////////////////////////////////////////////
// Grids
//////////////////////////////////////////////////////////////////////////

  Void testGrids()
  {
    verifyIO(
      GridBuilder()
           .setMeta(["title":"grid"])
           .addCol("a", ["dis":"Alpha", "alpha":Marker.val])
           .addCol("b")
           .addCol("c", ["charlie":Marker.val])
           .addRow(["a-0", "b-0", "c-0"])
           .addRow(["a-1", "b-1", "c-1"])
           .toGrid,
      Str<|ver:"3.0" title:"grid"
           a dis:"Alpha" alpha, b, c charlie
           "a-0", "b-0", "c-0"
           "a-1", "b-1", "c-1"
           |>,
      null)

   }

//////////////////////////////////////////////////////////////////////////
// Nesting
//////////////////////////////////////////////////////////////////////////

  Void testNesting()
  {
    // simple grid to nest
    abGrid := |Int s->Grid|
    {
      GridBuilder()
      .addCol("a").addCol("b")
      .addRow([n(s+0), n(s+1)]).addRow([n(s+2), n(s+3)])
      .toGrid
    }

    // nesting
    verifyIO(
      // grid value
      GridBuilder()
           .addCol("val")
           .addRow([ Number[n(1), n(2), n(3)] ])
           .addRow([ Etc.makeDict(["dis":"dict!", "marker":Marker.val]) ])
           .addRow([ abGrid(1) ])
           .addRow([ abGrid(5) ])
           .addRow([ Obj?[ Number[n(1), n(2)], Str["a", "b"]] ])
           .addRow([ Etc.makeDict([
                       "list": Number[n(-1), n(-2)],
                       "grid": abGrid(10),
                       "dict": Etc.makeDict(["a":Marker.val, "b":Marker.val])
                       ])
                   ])
           .toGrid,

      // zinc
      Str<|ver:"3.0"
           val
           [1, 2, 3]
           {dis:"dict!" marker}
           <<ver:"3.0"
           a,b
           1,2
           3,4>>
           <<
             ver:"3.0"
             a,b
             5,6
             7,8
           >>
           [ [1, 2], ["a", "b"] ]
           { list:[-1, -2] grid:<<
               ver:"3.0"
               a,b
               10,11
               12,13>> dict:{a b}}
             |>,

      // json
      null)

    // list inference
    verifyIO(
      // grid value
      GridBuilder()
           .addCol("val")
           .addRow([ Dict[Etc.makeDict(["a":"A"]), Etc.makeDict(["a":"A", "b":"B"])] ])
           .addRow([ Dict?[Etc.makeDict(["a":"A"]), null, Etc.makeDict(["a":"A", "b":"B"])] ])
           .toGrid,

      // zinc
      Str<|ver:"3.0"
           val
           [{a:"A"}, {a:"A" b:"B"}]
           [{a:"A"}, N, {a:"A" b:"B"}]
           |>,

      // json
      null)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verifyIO(Obj? val, Str? zinc, Str? json, Str? hson := null)
  {
    verifyZinc(val, zinc)
    verifyJson(val, json)
    verifyHayson(val, hson)
    verifyTrio(val)
    verifyBrio(val)
  }

  Void verifyZinc(Obj? val, Str? zinc)
  {
    // read from source
    if (zinc != null)
    {
      actual := ZincReader(zinc.in).readVal
      verifyValEq(actual, val)
      if (val isnot Grid) verifyZincErr("$zinc 123")
    }

    // round trip value
    s := StrBuf()
    writer := ZincWriter(s.out)
    writer.writeVal(val)
    actual := ZincReader(s.toStr.in).readVal
    verifyValEq(actual, val)
  }

  Void verifyZincErr(Str s)
  {
    verifyErr(ParseErr#) { ZincReader(s.in).readVal }
  }

  Void verifyJson(Obj? val, Str? json)
  {
    opts := Etc.dict1("v3", Marker.val)
    // read from source
    if (json != null)
    {
      actual := JsonReader(json.in, opts).readVal
      verifyValEq(actual, val)
    }

    // round trip value
    s := StrBuf()
    writer := JsonWriter(s.out, opts)
    writer.writeVal(val)
    actual := JsonReader(s.toStr.in, opts).readVal
    verifyValEq(actual, val)
  }

  Void verifyHayson(Obj? val, Str? hson)
  {
    // read from source
    if (hson != null)
    {
      actual := JsonReader(hson.in).readVal
      verifyValEq(actual, val)
    }

    // round trip value
    s := StrBuf()
    writer := JsonWriter(s.out)
    writer.writeVal(val)
    actual := JsonReader(s.toStr.in).readVal
    verifyValEq(actual, val)
  }

  Void verifyTrio(Obj? val)
  {
    // don't test null or strings with leading/trailing whitespace
    if (val == null) return
    if (val is Str && val != val.toStr.trim) return

    dict := Etc.makeDict(["foo":val])

    s := StrBuf()
    TrioWriter(s.out).writeDict(dict)
    actual := TrioReader(s.toStr.in).readDict["foo"]
    verifyValEq(actual, val)
  }


  Void verifyBrio(Obj? val)
  {
    buf := Buf()
    BrioWriter(buf.out).writeVal(val)
    buf.flip

    actual := BrioReader(buf.in).readVal
    verifyValEq(val, actual)
  }
}

