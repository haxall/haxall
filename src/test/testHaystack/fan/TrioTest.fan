//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jun 2010  Brian Frank  Creation
//

using haystack

**
** TrioTest
**
@Js
class TrioTest : HaystackTest
{
  Void testUseQuotes()
  {
    verifyUseQuotes("", true)
    verifyUseQuotes("a", false)
    verifyUseQuotes("A", false)
    verifyUseQuotes("Site-3 Ahu-2", false)
    verifyUseQuotes("3", true)
    verifyUseQuotes("[", true)
    verifyUseQuotes("C(foo)", true)
    verifyUseQuotes("Foo(xx)", true)
    verifyUseQuotes("ΔFoo(xx)", false)
    verifyUseQuotes("x:b", true)
    verifyUseQuotes("x\ny", true)
    verifyUseQuotes("@x", true)
    verifyUseQuotes("true", true)
    verifyUseQuotes("false", true)
    verifyUseQuotes("NAx", false)
  }

  private Void verifyUseQuotes(Str s, Bool expected)
  {
    verifyEq(TrioWriter.useQuotes(s), expected)
  }

  Void test()
  {
    m := Marker.val
    id := Ref.gen

    verifyTrio(
      Str<||>,
      [,])

    verifyTrio(
      Str<|x|>,
      [["x":m]])

    verifyTrio(
      Str<|multiLine
           doc:
             hello
             world

           code:
              -- b
            // foo
               bar|>,
      [["multiLine":m, "doc":"hello\nworld\n", "code":"  -- b\n// foo\n   bar"]])

    verifyTrio(
      Str<|// some stuff

           ---
           ---
           site
           geoAddr:13 main st
           ---

           ---
           // what it is
           site

           geoAddr:14 main st
           // that's right
           |>,
      [["site":m, "geoAddr":"13 main st"],
       ["site":m, "geoAddr":"14 main st"]])

    verifyTrio(
      Str<|a:hello$world
           b:Foo-123
          |>,
      [["a":"hello\$world", "b":"Foo-123"]])

    verifyTrio(
      Str<|a
           b:3
           // ignore

           c:foo
           -
           d:bar
           ----
           e:5 x
           |>,
      [["a":m, "b":n(3), "c":"foo"],
       ["d":"bar"],
       ["e":"5 x"]])

    verifyTrio(
      Str<|m
           bt:true
           bf: false
           i1: -123456
           i2: 1_2_3
           f1: 2.0
           f2: -5e+30
           d1: 3sec
           d2: -15min
           d3: 24hr
           u1: 45°C
           s: "foo\tbar\u00ab"
           u:`some/file`
           na: NA
           symbol: ^hot-water
           idNew:@13b27fda-284fd8e2
           idComplex:@foo:bar
           date: 2009-01-02
           time1: 13:05
           time2: 7:56
           time3: 6:12:34
           geoCoord: C(37.65,-77.61)
           |>,
      [[
        "m":m,
        "bt":true,
        "bf":false,
        "i1":n(-123456),
        "i2":n(123),
        "f1":n(2.0f),
        "f2":n(-5e+30f),
        "d1":n(3, "s"),
        "d2":n(-15, "min"),
        "d3":n(24, "hr"),
        "u1":n(45, "celsius"),
        "s":"foo\tbar\u00ab",
        "u":`some/file`,
        "na":NA.val,
        "symbol": Symbol("hot-water"),
        "idNew":Ref("13b27fda-284fd8e2"),
        "idComplex":Ref("foo:bar"),
        "date":Date("2009-01-02"),
        "time1":Time(13, 5, 0),
        "time2":Time(7, 56, 0),
        "time3":Time(6, 12, 34),
        "geoCoord": Coord(37.65f, -77.61f),
        ]])

    verifyTrio(
      Str<|fake:NaN
           big:INF
           small:-INF
           ref:@id
           d:2010-01-03
           t:true
           ---
           fake:"NaN"
           big:"INF"
           bad:"NA"
           small:"-INF"
           ref:"@id"
           d:"2010-01-03"
           t:"true"
           f:"false"
           n1:"300"
           n2:"-400"
           quoted:"\"Quoted String\""|>,
      [["fake":Number.nan, "big":Number.posInf, "small":Number.negInf,
        "ref":Ref("id"), "d":Date(2010, Month.jan, 3), "t": true],
        ["fake":"NaN", "big":"INF", "bad":"NA", "small":"-INF",
         "ref":"@id", "d": "2010-01-03", "t": "true", "f":"false",
         "n1":"300", "n2":"-400", "quoted":"\"Quoted String\""]])

    verifyTrio(
      Str<|id:@2015-12-29T14:22:39.364Z
           mod:2015-12-29T14:22:39.364Z
           str:2015-12-29 14:22:39.364Z|>,
       [["id":Ref("2015-12-29T14:22:39.364Z"),
          "mod":DateTime("2015-12-29T14:22:39.364Z UTC"),
          "str":"2015-12-29 14:22:39.364Z"]])

    // simple grid to nest
    abGrid := |Int s->Grid|
    {
      GridBuilder()
      .addCol("a").addCol("b")
      .addRow([n(s+0), n(s+1)]).addRow([n(s+2), n(s+3)])
      .toGrid
    }

    verifyTrio(
      Str<|name:foobar
           list1:[@a, @b]
           dict1:{a:"Alpha" b}
           grid1:Zinc:
             ver:"3.0"
             a,b
             1,2
             3,4
           list2:Zinc:
             ["hi", N, <<
             ver:"3.0"
             a,b
             10,11
             12,13>>]
           dict2:Zinc:
             {foo grid:<<
             ver:"3.0"
             a,b
             20,21
             22,23>>}
           doc:
             hi there
           |>,
       [["name":"foobar",
         "list1":Ref[Ref("a"), Ref("b")],
         "dict1":d(["a":"Alpha", "b":Marker.val]),
         "grid1":abGrid(1),
         "list2":["hi", null, abGrid(10)],
         "dict2":d(["foo":Marker.val, "grid":abGrid(20)]),
         "doc":"hi there"
         ]])

    verifyTrio(
      Str<|name:foobar
           trio:Trio:
             dis:"nested"
             foo
           |>,
       [["name":"foobar",
         "trio":d(["dis":"nested", "foo":Marker.val]),
         ]])

    verifyTrio(
      Str<|list:[
             13,
             "foo",
             {dis:"dict!", mark},
             ]
           children: [
             {fan, motor, equip},
             {damper, actuator, equip},
             ]
           |>,
       [["list":[n(13), "foo", d(["dis":"dict!", "mark":Marker.val])],
         "children": [d(["fan", "motor", "equip"]), d(["damper", "actuator", "equip"])]
         ]])

    verifyTrio(
      Str<|one: {a,b:123,c}
           two: {e, f:123, g }
           thr: {h i:123  j }
           |>,
      [["one":d(["a":m, "b":n(123), "c":m]),
        "two":d(["e":m, "f":n(123), "g":m]),
        "thr":d(["h":m, "i":n(123), "j":m])]])

    verifyTrio(
      Str<|---
           ---
           |>,
      [,])

    verifyTrio(
      Str<|---
           dis:a
           ---
           ---
           ---
           dis:b
           ---
           ---
           |>,
      [["dis":"a"],
        ["dis":"b"]])

  }

  Void testBigStr()
  {
    buf := StrBuf()
    2.pow(16).times { buf.add("A") }
    trio := "c0_body:${buf}"
    verifyTrio(trio, [["c0_body": "${buf}"]])
  }

  Void verifyTrio(Str str, [Str:Obj][] expected)
  {
    // try from str
    recs := TrioReader(str.in).readAllDicts
    verifyEq(recs.size, expected.size)
    recs.each |rec, i| { verifyDictEq(rec, expected[i]) }

    // round trip via TrioWriter
    s := StrBuf()
    TrioWriter(s.out).writeAllDicts(recs)
    str = s.toStr
    recs = TrioReader(str.in).readAllDicts
    verifyEq(recs.size, expected.size)
    recs.each |rec, i| { verifyDictEq(rec, expected[i]) }
  }

  Dict d(Obj x) { Etc.makeDict(x) }
}