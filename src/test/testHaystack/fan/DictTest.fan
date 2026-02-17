//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jun 2021  Brian Frank  Create
//

using xeto
using haystack

**
** DictTest
**
@Js
class DictTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  Void testDict()
  {
    // empty dict
    verifySame(Etc.dict0, Etc.dict0)
    verifySame(Etc.dict0, Etc.makeDict(Str:Obj?[:]))
    verifyDict(Str:Obj?[:])
    verifyEq(Etc.makeDict(null).typeof.qname, "xeto::EmptyDict")

    // test different sizes
    (1..10).each  |i| { verifyDictSize(i) }

    // dictx
    100.times
    {
      n := Str?[,]
      v := Obj?[,]
      acc := Str:Obj[:]
      6.times |i|
      {
        ni := (0..100).random < 70 ? "n_$i" : null
        vi := (0..100).random < 70 ? Number(i*100) : null
        n.add(ni)
        v.add(vi)
        if (ni != null && vi != null) acc[ni] = vi
      }
      a := Etc.dictx(n[0], v[0], n[1], v[1], n[2], v[2], n[3], v[3], n[4], v[4], n[5], v[5])
      e := Etc.dictFromMap(acc)
      verifyDictEq(a, e)
    }
  }

  private Void verifyDictSize(Int size)
  {
    map := Str:Obj?[:]
    size.times |i| { map['a'.plus(i).toChar] = n(i) }

    verifyDict(map.dup)

    // test old nullable versions of makeDict, makeDictX

    dict := Etc.makeDict(map)
    verifyDictEq(dict, map)

    maxFixed := 6
    if (size <= maxFixed)
      verifyEq(dict.typeof.qname, "haystack::Dict${size}")
    else
      verifyEq(dict.typeof.qname, "haystack::MapDict")

    /* deprecated
    switch (size)
    {
      case 1:   verifyFixedDict(1, Etc.makeDict1("a", n(0)), dict)
      case 2:   verifyFixedDict(2, Etc.makeDict2("a", n(0), "b", n(1)), dict)
      case 3:   verifyFixedDict(3, Etc.makeDict3("a", n(0), "b", n(1), "c", n(2)), dict)
      case 4:   verifyFixedDict(4, Etc.makeDict4("a", n(0), "b", n(1), "c", n(2), "d", n(3)), dict)
      case 5:   verifyFixedDict(5, Etc.makeDict5("a", n(0), "b", n(1), "c", n(2), "d", n(3), "e", n(4)), dict)
      case 6:   verifyFixedDict(6, Etc.makeDict6("a", n(0), "b", n(1), "c", n(2), "d", n(3), "e", n(4), "f", n(5)), dict)
      default:  verifyEq(dict.typeof.qname, "haystack::MapDict")
    }
    */

    // test non-null versions of dictFromMap, dictX

    dict = Etc.dictFromMap(map)
    verifyDictEq(dict, map)
    if (size <= maxFixed)
      verifyEq(dict.typeof.qname, "haystack::Dict${size}")
    else
      verifyEq(dict.typeof.qname, "haystack::NotNullMapDict")

    switch (size)
    {
      case 1:   verifyFixedDict(1, Etc.dict1("a", n(0)), dict)
      case 2:   verifyFixedDict(2, Etc.dict2("a", n(0), "b", n(1)), dict)
      case 3:   verifyFixedDict(3, Etc.dict3("a", n(0), "b", n(1), "c", n(2)), dict)
      case 4:   verifyFixedDict(4, Etc.dict4("a", n(0), "b", n(1), "c", n(2), "d", n(3)), dict)
      case 5:   verifyFixedDict(5, Etc.dict5("a", n(0), "b", n(1), "c", n(2), "d", n(3), "e", n(4)), dict)
      case 6:   verifyFixedDict(6, Etc.dict6("a", n(0), "b", n(1), "c", n(2), "d", n(3), "e", n(4), "f", n(5)), dict)
      default:  verifyEq(dict.typeof.qname, "haystack::NotNullMapDict")
    }

    // try out dictx
    switch (size)
    {
      case 1:   verifyFixedDict(1, Etc.dictx("a", n(0)), dict)
      case 2:   verifyFixedDict(2, Etc.dictx("a", n(0), "b", n(1)), dict)
      case 3:   verifyFixedDict(3, Etc.dictx("a", n(0), "b", n(1), "c", n(2)), dict)
      case 4:   verifyFixedDict(4, Etc.dictx("a", n(0), "b", n(1), "c", n(2), "d", n(3)), dict)
      case 5:   verifyFixedDict(5, Etc.dictx("a", n(0), "b", n(1), "c", n(2), "d", n(3), "e", n(4)), dict)
      case 6:   verifyFixedDict(6, Etc.dictx("a", n(0), "b", n(1), "c", n(2), "d", n(3), "e", n(4), "f", n(5)), dict)
      default:  verifyEq(dict.typeof.qname, "haystack::NotNullMapDict")
    }
  }

  Void verifyFixedDict(Int size, Dict a, Dict b)
  {
    verifyEq(a.typeof.qname, "haystack::Dict${size}")
    verifyEq(b.typeof.qname, "haystack::Dict${size}")
    verifyDictEq(a, b)
    verifyDictImpl(a, Etc.dictToMap(b))
  }

  Void verifyDict(Str:Obj? map)
  {
    d := Etc.makeDict(map)
    verifyDictImpl(d, map)

    acc := Str:Obj?[:]
    d.each |v, n|
    {
      acc[n] = v
      verifyEq(d[n], v)
      verifyEq(d.has(n), true)
      verifyEq(d.missing(n), false)
      verifyEq(d.trap(n, null), v)
    }
    verifyEq(acc.keys.sort, map.keys.sort)

    map["fooBar"] = "xxx"
    verifyEq(d.get("fooBar"), null)
    verifyEq(d.has("fooBar"), false)
    verifyEq(d.missing("fooBar"), true)
    verifyErr(UnknownNameErr#) { d->fooBar }
  }

//////////////////////////////////////////////////////////////////////////
// Dict Nulls
//////////////////////////////////////////////////////////////////////////

  Void testDictNulls()
  {
    verifyDictNull(Etc.dict1x("a", null), Str:Obj[:])

    verifyDictNull(Etc.dict2x("a", "A",  "b", "B"),  Str:Obj["a":"A", "b":"B"])
    verifyDictNull(Etc.dict2x("a", null, "b", "B"),  Str:Obj["b":"B"])
    verifyDictNull(Etc.dict2x("a", "A",  "b", null), Str:Obj["a":"A"])

    verifyDictNull(Etc.dict3x("a", "A",  "b", "B",  "c", "C"),   Str:Obj["a":"A", "b":"B", "c":"C"])
    verifyDictNull(Etc.dict3x("a", null, "b", "B",  "c", "C"),   Str:Obj["b":"B", "c":"C"])
    verifyDictNull(Etc.dict3x("a", "A",  "b", null, "c", "C"),   Str:Obj["a":"A", "c":"C"])
    verifyDictNull(Etc.dict3x("a", "A",  "b", "B",  "c", null),  Str:Obj["a":"A", "b":"B"])
    verifyDictNull(Etc.dict3x("a", null,  "b", null, "c", "C"),  Str:Obj["c":"C"])
    verifyDictNull(Etc.dict3x("a", null,  "b", null, "c", null), Str:Obj[:])

    verifyDictNull(Etc.dict4x("a", "A",  "b", "B",  "c", "C",  "d", "D"),  Str:Obj["a":"A", "b":"B", "c":"C", "d":"D"])
    verifyDictNull(Etc.dict4x("a", null, "b", "B",  "c", "C",  "d", "D"),  Str:Obj["b":"B", "c":"C", "d":"D"])
    verifyDictNull(Etc.dict4x("a", "A",  "b", null, "c", "C",  "d", "D"),  Str:Obj["a":"A", "c":"C", "d":"D"])
    verifyDictNull(Etc.dict4x("a", "A",  "b", "B",  "c", null, "d", "D"),  Str:Obj["a":"A", "b":"B", "d":"D"])
    verifyDictNull(Etc.dict4x("a", "A",  "b", "B",  "c", "C",  "d", null), Str:Obj["a":"A", "b":"B", "c":"C"])

    /*
    verifyDictNull(Etc.makeDict5("a", "A",  "b", "B",  "c", "C",  "d", "D",  "e", "E"),  Str:Obj["a":"A", "b":"B", "c":"C", "d":"D", "e":"E"])
    verifyDictNull(Etc.makeDict5("a", null, "b", "B",  "c", "C",  "d", "D",  "e", "E"),  Str:Obj["b":"B", "c":"C", "d":"D", "e":"E"])
    verifyDictNull(Etc.makeDict5("a", "A",  "b", null, "c", "C",  "d", "D",  "e", "E"),  Str:Obj["a":"A", "c":"C", "d":"D", "e":"E"])
    verifyDictNull(Etc.makeDict5("a", "A",  "b", "B",  "c", null, "d", "D",  "e", "E"),  Str:Obj["a":"A", "b":"B", "d":"D", "e":"E"])
    verifyDictNull(Etc.makeDict5("a", "A",  "b", "B",  "c", "C",  "d", null, "e", "E"),  Str:Obj["a":"A", "b":"B", "c":"C", "e":"E"])
    verifyDictNull(Etc.makeDict5("a", "A",  "b", "B",  "c", "C",  "d", "D",  "e", null), Str:Obj["a":"A", "b":"B", "c":"C", "d":"D"])

    verifyDictNull(Etc.makeDict6("a", "A",  "b", "B",  "c", "C",  "d", "D",  "e", "E",  "f", "F"),  Str:Obj["a":"A", "b":"B", "c":"C", "d":"D", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict6("a", null, "b", "B",  "c", "C",  "d", "D",  "e", "E",  "f", "F"),  Str:Obj["b":"B", "c":"C", "d":"D", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict6("a", "A",  "b", null, "c", "C",  "d", "D",  "e", "E",  "f", "F"),  Str:Obj["a":"A", "c":"C", "d":"D", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict6("a", "A",  "b", "B",  "c", null, "d", "D",  "e", "E",  "f", "F"),  Str:Obj["a":"A", "b":"B", "d":"D", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict6("a", "A",  "b", "B",  "c", "C",  "d", null, "e", "E",  "f", "F"),  Str:Obj["a":"A", "b":"B", "c":"C", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict6("a", "A",  "b", "B",  "c", "C",  "d", "D",  "e", null, "f", "F"),  Str:Obj["a":"A", "b":"B", "c":"C", "d":"D", "f":"F"])
    verifyDictNull(Etc.makeDict6("a", "A",  "b", "B",  "c", "C",  "d", "D",  "e", "E",  "f", null), Str:Obj["a":"A", "b":"B", "c":"C", "d":"D", "e":"E"])
    verifyDictNull(Etc.makeDict6("a", null,  "b", "B",  "c", "C",  "d", "D",  "e", "E",  "f", null), Str:Obj["b":"B", "c":"C", "d":"D", "e":"E"])
    verifyDictNull(Etc.makeDict6("a", null,  "b", "B",  "c", null,  "d", "D",  "e", "E",  "f", null), Str:Obj["b":"B", "d":"D", "e":"E"])
    verifyDictNull(Etc.makeDict6("a", null,  "b", "B",  "c", null,  "d", "D",  "e", null,  "f", null), Str:Obj["b":"B", "d":"D"])
    verifyDictNull(Etc.makeDict6("a", null,  "b", null,  "c", null,  "d", "D",  "e", null,  "f", null), Str:Obj["d":"D"])
    verifyDictNull(Etc.makeDict6("a", null,  "b", null,  "c", null,  "d", null,  "e", null,  "f", null), Str:Obj[:])
    */

    // map 1 - 6
    verifyDictNull(Etc.makeDict(["a":"A",  "b":"B",  "c":"C",  "d":"D",  "e":"E",  "f":"F"]),  Str:Obj["a":"A", "b":"B", "c":"C", "d":"D", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict(["a":null, "b":"B",  "c":"C",  "d":"D",  "e":"E",  "f":"F"]),  Str:Obj["b":"B", "c":"C", "d":"D", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict(["a":"A",  "b":null, "c":"C",  "d":"D",  "e":"E",  "f":"F"]),  Str:Obj["a":"A", "c":"C", "d":"D", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict(["a":"A",  "b":"B",  "c":null, "d":"D",  "e":"E",  "f":"F"]),  Str:Obj["a":"A", "b":"B", "d":"D", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict(["a":"A",  "b":"B",  "c":"C",  "d":null, "e":"E",  "f":"F"]),  Str:Obj["a":"A", "b":"B", "c":"C", "e":"E", "f":"F"])
    verifyDictNull(Etc.makeDict(["a":"A",  "b":"B",  "c":"C",  "d":"D",  "e":null, "f":"F"]),  Str:Obj["a":"A", "b":"B", "c":"C", "d":"D", "f":"F"])
    verifyDictNull(Etc.makeDict(["a":"A",  "b":"B",  "c":"C",  "d":"D",  "e":"E",  "f":null]), Str:Obj["a":"A", "b":"B", "c":"C", "d":"D", "e":"E"])

    // over six
    verifyDictNull(Etc.makeDict(["a":"A", "b":"B", "c":"C", "d":"D", "e":"E", "f":"F", "g":"G"]), Str:Obj["a":"A", "b":"B", "c":"C", "d":"D", "e":"E", "f":"F", "g":"G"])
    verifyDictNull(Etc.makeDict(["a":"A", "b":"B", "c":null, "d":"D", "e":"E", "f":"F", "g":"G"]), Str:Obj["a":"A", "b":"B", "d":"D", "e":"E", "f":"F", "g":"G"], false)
    verifyDictNull(Etc.makeDict(["a":null, "b":"B", "c":null, "d":"D", "e":"E", "f":"F", "g":"G"]), Str:Obj["b":"B", "d":"D", "e":"E", "f":"F", "g":"G"], false)
    verifyDictNull(Etc.makeDict(["a":null, "b":"B", "c":null, "d":"D", "e":"E", "f":"F", "g":null]), Str:Obj["b":"B", "d":"D", "e":"E", "f":"F"], false)

    // his item
    ts := DateTime.now
    verifyDictNull(HisItem(ts, "x"), Str:Obj["ts":ts, "val":"x"])
    verifyDictNull(HisItem(ts, null), Str:Obj["ts":ts])
  }

  Void verifyDictNull(Dict d, Str:Obj expected, Bool fixed := true)
  {
    actual := Str:Obj[:]
    d.each |v, n| { actual[n] = v }
    verifyEq(actual, expected)

    actualWhile := Str:Obj[:]
    d.eachWhile |v, n| { actualWhile[n] = v; return null }
    verifyEq(actualWhile, expected)

    if (d is HisItem) return

    if (expected.size == 0)
      verifySame(d, Etc.dict0)
    else if (expected.size <= 6 && fixed)
      verifyEq(d.typeof.qname, "haystack::Dict${expected.size}")
    else
      verifyEq(d.typeof.qname, "haystack::MapDict")
  }

//////////////////////////////////////////////////////////////////////////
// Map
//////////////////////////////////////////////////////////////////////////

  Void testMap()
  {
    verifyMap(Etc.dict0)
    verifyMap(Etc.dict1("one", n(1)))
    verifyMap(Etc.dict2("one", n(1), "two", n(2)))
    verifyMap(Etc.dict3("one", n(1), "two", n(2), "three", n(3)))
    verifyMap(Etc.dict4("one", n(1), "two", n(2), "three", n(3), "four", n(4)))
    verifyMap(Etc.dict5("one", n(1), "two", n(2), "three", n(3), "four", n(4), "five", n(5)))
    verifyMap(Etc.dict6("one", n(1), "two", n(2), "three", n(3), "four", n(4), "five", n(5), "six", n(6)))
    verifyMap(Etc.makeDict(["a":n(1), "b":n(2), "c":n(3), "d":n(4), "e":n(5), "f":n(6), "g":n(7)]))
  }

  Void verifyMap(Dict a)
  {
    b := a.map |v| { (Number)v + n(100) }
    // echo("---> $a [$a.typeof]")
    // echo("   > $b [$b.typeof]")
    a.each |v, k| { verifyEq(b[k], (Number)v + n(100)) }
  }

//////////////////////////////////////////////////////////////////////////
// WrapWithSpec
//////////////////////////////////////////////////////////////////////////

  Void testWrapWithSpec()
  {
    s := TestWrapWithSpec.specRef
    verifyWrapWithSpec(Etc.dict0, ["spec":s])
    verifyWrapWithSpec(Etc.dict1("a", n(3)), ["a":n(3), "spec":s])
    verifyWrapWithSpec(Etc.dict2("a", "A", "b", "B"), ["a":"A", "b":"B", "spec":s])
    verifyWrapWithSpec(Etc.dict1("spec", s), ["spec":s])
    verifyWrapWithSpec(Etc.dict2("a", m, "spec", s), ["a":m, "spec":s])
    verifyWrapWithSpec(Etc.dict2("a", m, "spec", Ref("Override")), ["a":m, "spec":Ref("Override")])
  }

  Void verifyWrapWithSpec(Dict d, Str:Obj expect)
  {
    w := TestWrapWithSpec(d)
    verifyDictImpl(w, expect)
  }
}

**************************************************************************
** TestWrapWithSpec
**************************************************************************

@Js
internal const class TestWrapWithSpec : WrapWithSpecDict
{
  new make(Dict wrapped) : super(wrapped) {}

  static once Ref specRef() { Ref("hx.test.xeto::EquipA") }
  override Ref defaultSpecRef() { specRef }
}

