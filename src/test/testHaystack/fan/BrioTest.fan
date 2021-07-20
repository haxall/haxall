//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Nov 2015  Brian Frank  Creation
//

using haystack

**
** BrioTest
**
class BrioTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Consts
//////////////////////////////////////////////////////////////////////////

  Void testConsts()
  {
    cp := BrioConsts.cur

    verifyConsts(cp, "", 0)
    verifyConsts(cp, "Obj", 1)
    verifyConsts(cp, "New_York", 26)
    verifyConsts(cp, "°F", 730)

    // 3.0.15 (May 2018)
    verifyConsts(cp, "accept-charset", 748)
    verifyConsts(cp, "rules", 846)
    verifyConsts(cp, "viz", 871)

    // 3.0.175 (Nov 2018)
    verifyConsts(cp, "accept", 872)
    verifyConsts(cp, "ver", 945)

    // 3.0.27 (Nov 2020)
    verifyConsts(cp, "airRef", 970, null, false)

    // max safe code
    verifyIO("what", 7)    // inline
    verifyIO("knot", 3)    // safe
    verifyIO("post", 3)    // safe
    verifyIO("node", 3)    // safe

    // maxStrCode option using: 26 New_York
    verifyIO("New_York", 2)
    verifyIO("New_York", 11) { it.maxStrCode = -1 }
    verifyIO("New_York", 11) { it.maxStrCode = 25 }
    verifyIO("New_York", 2)  { it.maxStrCode = 26 }
    verifyIO("New_York", 2)  { it.maxStrCode = 27 }
  }


  Void verifyConsts(BrioConsts cp, Str val, Int code, Int? max := null, Bool safe := true)
  {
    verifyEq(cp.encode(val, max ?: cp.maxSafeCode) , safe ? code : null)
    verifyEq(cp.decode(code), val)
  }

//////////////////////////////////////////////////////////////////////////
// Var Int
//////////////////////////////////////////////////////////////////////////

  Void testVarInt()
  {
    // Explicit checks along boundaries:
    // - 0xxx: one byte (0 to 127)
    // - 10xx: two bytes (128 to 16_383)
    // - 110x: four bytes (16_384 to 536_870_911)
    // - 1110: nine bytes (536_870_912 .. Int.maxVal)
    vals  := [-1, 0, 30, 64, 127, 128, 1000, 16_383, 16_384, 500_123, 536_870_911, 536_870_912, 123_456_789_123]
    sizes := [1,  1,  1,  1,   1,   2,    2,      2,      4,       4,           4,           9,               9]

    buf := Buf()
    out := buf.out
    vals.each |v, i|
    {
      oldSize := buf.size
      BrioWriter(out).encodeVarInt(v)
      newSize := buf.size
      verifyEq(newSize - oldSize, sizes[i])
    }

    in := buf.flip.in
    vals.each |v, i|
    {
      x := BrioReader(in).decodeVarInt
      verifyEq(v, x)
    }

    // Random checks against boundaries
    boundA := 127
    boundB := 16_383
    boundC := 536_870_911
    vals.clear
    10_000.times |i|
    {
      j := (1..8).random
      switch (j)
      {
        case 0:  vals.add((0..boundA).random)
        case 1:  vals.add((boundA..boundB).random)
        case 2:  vals.add((boundB..boundC).random)
        case 3:  vals.add((boundA-10..boundA+10).random)
        case 4:  vals.add((boundB-10..boundB+10).random)
        case 5:  vals.add((boundC-20..boundC+10).random)
        case 6:  vals.add(-1)
        default: vals.add((Int.random * Int.random).abs)
      }
    }

    buf = Buf()
    vals.each |v| { BrioWriter(buf.out).encodeVarInt(v) }
    in = buf.flip.in
    vals.each |v, i|
    {
      x := BrioReader(in).decodeVarInt
      verifyEq(v, x)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Test Obj
//////////////////////////////////////////////////////////////////////////

  Void testIO()
  {
    // scalars
    verifyIO(null, 1)
    verifyIO(Marker.val, 1)
    verifyIO(NA.val, 1)
    verifyIO(Remove.val, 1)
    verifyIO(true, 1)
    verifyIO(false, 1)
    verifyIO(n(12), 4)
    verifyIO(n(123_456_789), 6)
    verifyIO(n(123_456_789, "°F"), 7)
    verifyIO(n(123_456.789f, "°F"), 11)
    verifyIO(n(123_456_789, "_foo"), 11)
    verifyIO(n(0x7fff), 4)
    verifyIO(n(0x7fff+1), 6)
    verifyIO(n(-32767 ), 4)
    verifyIO(n(-32768), 6)
    verifyIO(n(0x7fff_ffff), 6)
    verifyIO(n(0x8000_0000), 10)
    verifyIO(n(-2147483648), 6)
    verifyIO(n(-2147483649), 10)
    verifyIO("", 2)
    verifyIO("hello °F world!", 3+16)
    verifyIO(`http://foo/?°F`)
    verifyIO("siteRef", 3)
    verifyIO("New_York", 2)
    verifyIO(Ref("1deb31b8-7508b187"), 10)
    verifyIO(Ref("1debX1b8-7508b187"), 21)
    verifyIO(Ref("1deb31b8.7508b187"), 21)
    verifyIO(Ref("1deb31b8-7508b187", "hi!"), 13)
    verifyIO(Ref("1deb31b8-7508b187", "hi!"), 10) { it.encodeRefDis = false }
    verifyIO(Symbol("coolingTower"), 3)
    verifyIO(Symbol("foo-bar"), 3+7)
    verifyIO(DateTime("2015-11-30T12:02:33.378-05:00 New_York"), 10)
    verifyIO(DateTime("2015-11-30T12:03:57-05:00 New_York"), 6)
    verifyIO(DateTime("2015-11-30T12:03:57.000123-05:00 New_York"), 10)
    verifyIO(DateTime("2000-01-01T00:00:00+01:00 Warsaw"), 13)
    verifyIO(DateTime("2000-01-01T00:00:00.832+01:00 Warsaw"), 17)
    verifyIO(DateTime("1999-06-07T01:02:00-04:00 New_York"), 6)
    verifyIO(DateTime("1950-06-07T01:02:00-04:00 New_York"), 6)
    verifyIO(DateTime("1950-06-07T01:02:00.123-04:00 New_York"), 10)
    verifyIO("foo!".toBuf, 6)
    verifyIO(Etc.emptyDict, 1)
    verifyIO(Obj?[,], 1)
    verifyIO(Bin("text/plain"), 3)
    verifyIO(Bin("text/foobar"), 4+11)
    verifyIO(Span(SpanMode.lastWeek), 4+8)
    verifyIO(XStr("Foo", "bar"), null) // 1+2+3+2+3)

    // all different types
    verifyIO(["m":Marker.val, "na":NA.val, "bf":false, "bt":true, "n":n(123), "s":"hi",
      "r":Ref.gen, "u":`a/b`, "d":Date.today, "t":Time.now, "dt":DateTime.now,
      "c": Coord(84f, -123f), "bin":Bin("text/plain; charset=utf-8")])

    // with and with/out units
    verifyIO(["a": n(2), "b": n(1.2f, "kW"), "c": n(123456789, "°F"), "d":n(-3, "_foo")])

    // dict nulls tags are not encoded
    Dict dict := verifyIO(["x":null, "y":Remove.val, "z":"foo"])
    map := Str:Obj?[:]
    dict.each |v, n| { map[n] = v }
    verifyEq(map.keys.sort, ["y", "z"])
    verifyEq(map, Str:Obj?["y":Remove.val, "z":"foo"])

    // typical spark
    verifyIO(["spark": Marker.val, "ruleRef": Ref.gen,
              "targetRef": Ref("Gathersburg.RTU-2.Fan"),
              "siteRef": Ref("Gathersburg", "Site! Δ°F"),
              "equipRef": Ref("Gathersburg.RTU-2"),
              "pointRef": Ref("Gathersburg.RTU-2.Fan"),
              "date": Date.today,
              "periods": "CWAPE7APHvAP",
              "dur": n(0.75f, "hr"),
              "cost": n(24, "\$"),
              "times": "2:30a (15min), 5:15a (15min), 8:15a (15min)"])

     // grids
     verifyIO(ZincReader(
       """ver:"2.0"
          a,b,c,d
          @foo-bar,43,T,NA
          """.in).readGrid)
     // grids
     verifyIO(ZincReader(
       """ver:"2.0" foo bar n:3
          a dis:"A" metaFoo
          @foo-bar
          N
          R
          NA
          T
          F
          INF
          -INF
          NaN
          4kW
          -12.34kW
          "hello\nworld"
          `file.txt`
          2015-11-29
          2015-11-29T10:46:44.187-05:00 New_York
          C(1, -2)
          """.in).readGrid)

     // intern
     interns := [
       "s1":"low", "s2":"low",
       "d1":Date.today, "d2":Date.today,
       "r1":Ref("foo"), "r2":Ref("foo"),
       "y1":Symbol("foo"), "y2":Symbol("foo"),
       "dict1":Etc.makeDict(["fooBar":"low"]),
       "dict2":Etc.makeDict(["fooBar":Date.today])
       ]
     x := verifyIO(interns)
     verifySame(x->s1, x->s2)
     verifySame(x->d1, x->d2)
     verifySame(x->y1, x->y2)
     verifySame(x->dict1->fooBar, x->s1)
     verifySame(x->dict2->fooBar, x->d1)
     verifySame(Etc.dictNames(x->dict1).first, Etc.dictNames(x->dict2).first)

    // nested
    verifyIO([
      "list":["a", `foo`, Date.today, null, Marker.val],
      "dict": Etc.makeDict(["id":Ref.gen, "foo":Marker.val, "dis":"Hi!"]),
      "nestedList": Obj?[ Str["a", "b"], Number?[null, n(123, "°F")] ],
      ])

     // big one
     big := Str:Obj[:]
     0x7fff.times |i| { big["t$i"] = n(i) }
     verifyIO(big)
  }

  internal Obj? verifyIO(Obj? x, Int? size := null, |BrioWriter|? f := null)
  {
    if (x is Map) x = Etc.makeDict(x)

    buf := Buf()
    writer := BrioWriter(buf.out)
    if (f != null) f(writer)
    writer.writeVal(x)
    buf.flip

    if (size != null) verifyEq(buf.size, size)

    y := BrioReader(buf.in).readVal
    if (writer.encodeRefDis)
      verifyValEq(x, y)
    else
      verifyValEq(Ref(x.toStr), y)
    return y
  }

}