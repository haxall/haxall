//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jun 2009  Brian Frank  Create
//

using haystack

**
** EtcTest
**
@Js
class EtcTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Dict Name
//////////////////////////////////////////////////////////////////////////

  Void testTagName()
  {
    verifyTagName("", false)

    verifyTagName("2", false)
    verifyTagName("-", false)
    verifyTagName(":", false)
    verifyTagName("#", false)
    verifyTagName("P", false)
    verifyTagName("x", true)
    verifyTagName("_", false)

    verifyTagName("xy", true)
    verifyTagName("x3", true)
    verifyTagName("xG", true)
    verifyTagName("Q3", false)
    verifyTagName("x-", false)
    verifyTagName("x:", false)
    verifyTagName("x\u012f", false)
    verifyTagName("x,", false)
    verifyTagName("3x", false)
    verifyTagName("#@", false)
    verifyTagName("_x", true)
    verifyTagName("_3", true)
    verifyTagName("__", false)

    verifyTagName("x3y", true)
    verifyTagName("x3Z", true)
    verifyTagName("x:y", false)
    verifyTagName("x:3", false)
    verifyTagName("x:-", false)
    verifyTagName("x:@", false)
  }

  Void verifyTagName(Str n, Bool ok)
  {
    verifyEq(Etc.isTagName(n), ok)
  }

//////////////////////////////////////////////////////////////////////////
// Tag Name
//////////////////////////////////////////////////////////////////////////

  Void testToTagName()
  {
    verifyEq(Etc.toTagName("x"), "x")
    verifyEq(Etc.toTagName("Q"), "q")
    verifyEq(Etc.toTagName("3"), "v3")
    verifyEq(Etc.toTagName("Foo Bar"), "fooBar")
    verifyEq(Etc.toTagName("Foo_Bar"), "foo_Bar")
    verifyEq(Etc.toTagName("_"), "v_")
    verifyEq(Etc.toTagName("__"), "v__")
    verifyEq(Etc.toTagName("_3"), "_3")
    verifyEq(Etc.toTagName("_hi_there"), "_hi_there")
    verifyEq(Etc.toTagName("Foo 33 Bar 55"), "foo33Bar55")
    verifyEq(Etc.toTagName("_ foo %\n | bar _ baz"), "_FooBar_Baz")
    verifyEq(Etc.toTagName("-"), "v")
    verifyEq(Etc.toTagName("!"), "v")
    verifyEq(Etc.toTagName("!!"), "v")
    verifyEq(Etc.toTagName("#3"), "v3")
    verifyEq(Etc.toTagName("SAT"), "sat")
    verifyEq(Etc.toTagName("SAT3"), "sat3")
    verifyEq(Etc.toTagName("SAT-3"), "sat_3")
    verifyEq(Etc.toTagName("SAT #3"), "sat3")
    verifyEq(Etc.toTagName("SAT Foo"), "satFoo")
    verifyEq(Etc.toTagName("SAT TEMP"), "satTEMP")
    verifyEq(Etc.toTagName("IO"), "io")
    verifyEq(Etc.toTagName("IO-Foo"), "io_Foo")
    verifyEq(Etc.toTagName("foo.bar-baz/roo"), "foo_bar_baz_roo")
    verifyEq(Etc.toTagName(".foo"), "v_foo")
    verifyEq(Etc.toTagName("-foo"), "v_foo")
    verifyEq(Etc.toTagName("foo."), "foo")
    verifyEq(Etc.toTagName("foo.x"), "foo_x")
    verifyEq(Etc.toTagName("foo/"), "foo")
  }

//////////////////////////////////////////////////////////////////////////
// File Name
//////////////////////////////////////////////////////////////////////////

  Void testToFileName()
  {
    verifyFileName("", "x")
    verifyFileName(" ", "x")
    verifyFileName(" foo ", "foo")
    verifyFileName(".a-b~c d", ".a-b~c d")
    verifyFileName("^Alpha|Bar&c", "-Alpha-Bar-c")
  }

  Void verifyFileName(Str n, Str expected)
  {
    verifyEq(Etc.isFileName(n), n == expected)
    verifyEq(Etc.toFileName(n), expected)
  }

//////////////////////////////////////////////////////////////////////////
// Name Starts With
//////////////////////////////////////////////////////////////////////////

  Void testNameStartsWith()
  {
    verifyEq(Etc.nameStartsWith("foo", "foo"), true)
    verifyEq(Etc.nameStartsWith("foo", "fooB"), true)
    verifyEq(Etc.nameStartsWith("foo", "fooBar"), true)
    verifyEq(Etc.nameStartsWith("foo", "fool"), false)
    verifyEq(Etc.nameStartsWith("foo", "fox"), false)
    verifyEq(Etc.nameStartsWith("foo", "f"), false)
  }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  Void testDict()
  {
    // empty dict
    verifySame(Etc.emptyDict, Etc.emptyDict)
    verifySame(Etc.emptyDict, Etc.makeDict(Str:Obj?[:]))
    verifyDict(Str:Obj?[:])
    verifyEq(Etc.makeDict(null).typeof.qname, "haystack::EmptyDict")

    // test different sizes
    (1..10).each  |i| { verifyDictSize(i) }
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
  }

  Void verifyFixedDict(Int size, Dict a, Dict b)
  {
    verifyEq(a.typeof.qname, "haystack::Dict${size}")
    verifyEq(b.typeof.qname, "haystack::Dict${size}")
    verifyDictEq(a, b)
  }

  Void verifyDict(Str:Obj? map)
  {
    d := Etc.makeDict(map)
    verifyEq(d.isEmpty, map.isEmpty)

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
    verifyEq(d.get("fooBar", 8), 8)
    verifyEq(d.has("fooBar"), false)
    verifyEq(d.missing("fooBar"), true)
    verifyErr(UnknownNameErr#) { d->fooBar }
  }

//////////////////////////////////////////////////////////////////////////
// Dict Nulls
//////////////////////////////////////////////////////////////////////////

  Void testDictNulls()
  {
    verifyDictNull(Etc.makeDict1("a", null), Str:Obj[:])

    verifyDictNull(Etc.makeDict2("a", "A",  "b", "B"),  Str:Obj["a":"A", "b":"B"])
    verifyDictNull(Etc.makeDict2("a", null, "b", "B"),  Str:Obj["b":"B"])
    verifyDictNull(Etc.makeDict2("a", "A",  "b", null), Str:Obj["a":"A"])

    verifyDictNull(Etc.makeDict3("a", "A",  "b", "B",  "c", "C"),   Str:Obj["a":"A", "b":"B", "c":"C"])
    verifyDictNull(Etc.makeDict3("a", null, "b", "B",  "c", "C"),   Str:Obj["b":"B", "c":"C"])
    verifyDictNull(Etc.makeDict3("a", "A",  "b", null, "c", "C"),   Str:Obj["a":"A", "c":"C"])
    verifyDictNull(Etc.makeDict3("a", "A",  "b", "B",  "c", null),  Str:Obj["a":"A", "b":"B"])
    verifyDictNull(Etc.makeDict3("a", null,  "b", null, "c", "C"),  Str:Obj["c":"C"])
    verifyDictNull(Etc.makeDict3("a", null,  "b", null, "c", null), Str:Obj[:])

    verifyDictNull(Etc.makeDict4("a", "A",  "b", "B",  "c", "C",  "d", "D"),  Str:Obj["a":"A", "b":"B", "c":"C", "d":"D"])
    verifyDictNull(Etc.makeDict4("a", null, "b", "B",  "c", "C",  "d", "D"),  Str:Obj["b":"B", "c":"C", "d":"D"])
    verifyDictNull(Etc.makeDict4("a", "A",  "b", null, "c", "C",  "d", "D"),  Str:Obj["a":"A", "c":"C", "d":"D"])
    verifyDictNull(Etc.makeDict4("a", "A",  "b", "B",  "c", null, "d", "D"),  Str:Obj["a":"A", "b":"B", "d":"D"])
    verifyDictNull(Etc.makeDict4("a", "A",  "b", "B",  "c", "C",  "d", null), Str:Obj["a":"A", "b":"B", "c":"C"])

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
      verifySame(d, Etc.emptyDict)
    else if (expected.size <= 6 && fixed)
      verifyEq(d.typeof.qname, "haystack::Dict${expected.size}")
    else
      verifyEq(d.typeof.qname, "haystack::MapDict")
  }

//////////////////////////////////////////////////////////////////////////
// Dict Updates
//////////////////////////////////////////////////////////////////////////

  Void testDictUpdate()
  {
    d := Etc.makeDict(["a":n(1)])
    verifyEq(d.typeof.qname, "haystack::Dict1")
    verifyDictEq(d, ["a":n(1)])

    verifySame(Etc.dictRename(d, "foo", "bar"), d)
    d = Etc.dictRename(d, "a", "b")
    verifyEq(d.typeof.qname, "haystack::Dict1")
    verifyDictEq(d, ["b":n(1)])

    verifySame(Etc.dictRemove(d, "foo"), d)
    d = Etc.dictRemove(d, "b")
    verifyEq(d.typeof.qname, "haystack::EmptyDict")
    verifyDictEq(d, [:])

    d = Etc.dictSet(d, "x", n(3))
    verifyEq(d.typeof.qname, "haystack::Dict1")
    verifyDictEq(d, ["x":n(3)])

    d = Etc.dictSet(d, "x", n(4))
    verifyEq(d.typeof.qname, "haystack::Dict1")
    verifyDictEq(d, ["x":n(4)])

    d = Etc.dictSet(d, "y", n(5))
    verifyEq(d.typeof.qname, "haystack::Dict2")
    verifyDictEq(d, ["x":n(4), "y":n(5)])

    verifySame(d, Etc.dictRemoveAllWithVal(d, null))
    verifySame(d, Etc.dictRemoveAllWithVal(d, "foo"))
    verifySame(d, Etc.dictRemoveAllWithVal(d, n(3)))
    verifyDictEq(Etc.dictRemoveAllWithVal(d, n(4)), ["y":n(5)])

    d = Etc.emptyDict
    verifySame(d, Etc.dictRemoveNulls(d))
    d = Etc.makeDict(["a":n(1), "b":n(2)])
    verifySame(d, Etc.dictRemoveNulls(d))
    d = Etc.makeDict(["a":n(1), "x":null, "b":n(2)])
    verifyDictEq(Etc.dictRemoveNulls(d), ["a":n(1), "b":n(2)])

    d = Etc.dictSet(d, "c", n(3))
    verifySame(Etc.dictRemoveAll(d, Str[,]), d)
    verifySame(Etc.dictRemoveAll(d, Str["foo"]), d)
    d = Etc.dictRemoveAll(d, Str["a", "c", "x"])
    verifyDictEq(d, ["b":n(2)])
  }

//////////////////////////////////////////////////////////////////////////
// Dict Merge
//////////////////////////////////////////////////////////////////////////

  Void testMerge()
  {
    empty := Etc.emptyDict
    x := Etc.makeDict(["x":n(123)])
    verifySame(Etc.dictMerge(empty, empty), empty)
    verifySame(Etc.dictMerge(empty, x), x)
    verifySame(Etc.dictMerge(x, null), x)
    verifySame(Etc.dictMerge(x, empty), x)

    verifyMerge(empty, ["a":m], ["a":m])
    verifyMerge(empty, ["a":Remove.val], empty)
    verifyMerge(empty, ["a":m, "b":Remove.val], ["a":m])
    verifyMerge(["a":m, "b":"!"], empty, ["a":m, "b":"!"])
    verifyMerge(["a":m, "b":"!"], ["b":Remove.val], ["a":m])
    verifyMerge(["a":m, "b":"!"], ["c":Remove.val], ["a":m, "b":"!"])
  }

  Void verifyMerge(Obj a, Obj b, Obj expected)
  {
    actual := Etc.dictMerge(Etc.makeDict(a), b)
    // echo("--> $a | $b => $actual")
    verifyDictEq(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// Eq
//////////////////////////////////////////////////////////////////////////

  Void testEq()
  {
    // lists
    verifyEtcListEq([,], [,], true)
    verifyEtcListEq(Number[,], Str[,], true)
    verifyEtcListEq(["A"], ["A"], true)
    verifyEtcListEq(["A"], ["B"], false)
    verifyEtcListEq(["A"], [n(3)], false)
    verifyEtcListEq(["A"], [null], false)
    verifyEtcListEq(["a", n(2)], ["a", n(2)], true)
    verifyEtcListEq(["a", "b"], ["a", "b"], true)
    verifyEtcListEq(Str["a", "b"], Obj["a", "b"], true)

    // dicts
    verifyEtcDictEq([:], [:], true)
    verifyEtcDictEq(["a":"!"], ["a":"!"], true)
    verifyEtcDictEq(["a":"!", "b":n(123)], ["b":n(123), "a":"!"], true)
    verifyEtcDictEq(["a":"!", "b":n(345)], ["a":"!", "b":n(123)], false)
    verifyEtcDictEq(["a":"x", "b":n(123)], ["a":"!", "b":n(123)], false)
    verifyEtcDictEq(["a":"!", "b":n(123)], ["a":"!"], false)
    verifyEtcDictEq(["a":"!", "b":n(123)], ["b":n(123)], false)
    verifyEtcDictEq(["a":null], ["a":null], true)
    verifyEtcDictEq(["a":null], ["b":null], true)
    verifyEtcDictEq(["a":"!"],  ["a":"!", "x":null], true)
    verifyEtcDictEq(["a":"!", "x":null],  ["a":"!"], true)
    verifyEtcDictEq(["a":"!"],  ["a":"?", "x":null], false)

    // nesting
    verifyEtcListEq([Number[n(1), n(2)]], [Obj[n(1), n(2)]], true)
    verifyEtcListEq([Number[n(1), n(2)]], [Obj[n(1), n(3)]], false)
    verifyEtcListEq([Etc.makeDict(["foo":n(1), "bar":n(2)])], [Etc.makeDict(["bar":n(2), "foo":n(1)])], true)
    verifyEtcListEq([Etc.makeDict(["foo":n(1), "bar":n(3)])], [Etc.makeDict(["bar":n(2), "foo":n(1)])], false)
    verifyEtcDictEq(["a":Obj[n(1), n(2)]], ["a":Number[n(1), n(2)]], true)
    verifyEtcDictEq(["x":Obj[n(1), Etc.makeDict(["foo":"bar"])]], ["x":Obj[n(1), Etc.makeDict(["foo":"bar"])]], true)
    verifyEtcDictEq(["x":Obj[n(1), Etc.makeDict(["foo":"bar"])]], ["x":Obj[n(1), Etc.makeDict(["foo":"bar!"])]], false)
  }

  Void verifyEtcListEq(Obj?[] a, Obj?[] b, Bool expected)
  {
    // echo("$a ?= $b => " + Etc.listEq(a, b))
    verifyEq(Etc.listEq(a, a), true)
    verifyEq(Etc.listEq(b, b), true)
    verifyEq(Etc.listEq(a, b), expected)
    verifyEq(Etc.listEq(b, a), expected)
    verifyEq(Etc.eq(a, b), expected)
    verifyEq(Etc.eq(b, a), expected)
    verifyEtcGridEq(a, b, expected)
  }

  Void verifyEtcDictEq(Obj ao, Obj bo, Bool expected)
  {
    a := Etc.makeDict(ao)
    b := Etc.makeDict(bo)
    // echo("$a ?= $b => " + Etc.dictEq(a, b))
    verifyEq(Etc.dictEq(a, a), true)
    verifyEq(Etc.dictEq(b, b), true)
    verifyEq(Etc.dictEq(a, b), expected)
    verifyEq(Etc.dictEq(b, a), expected)
    verifyEq(Etc.eq(a, b), expected)
    verifyEq(Etc.eq(b, a), expected)
    verifyEtcGridEq(a, b, expected)
  }

  Void verifyEtcGridEq(Obj? ao, Obj? bo, Bool expected)
  {
    ga := GridBuilder().addCol("x").addRow([ao]).toGrid
    gb := GridBuilder().addCol("x").addRow([bo]).toGrid
    verifyEq(Etc.gridEq(ga, gb), expected)
    verifyEq(Etc.eq(ga, gb), expected)
  }

//////////////////////////////////////////////////////////////////////////
// Grid
//////////////////////////////////////////////////////////////////////////

 Void testGrids()
 {
   verifySame(Etc.emptyGrid, Etc.emptyGrid)
   verifySame(Etc.makeEmptyGrid(null), Etc.emptyGrid)

   verifySame(Etc.makeEmptyGrid(Etc.emptyDict), Etc.emptyGrid)
   verifyNotSame(Etc.makeEmptyGrid(["foo":"bar"]), Etc.emptyGrid)
   verifyDictEq(Etc.makeEmptyGrid(["foo":"bar"]).meta, ["foo":"bar"])

   verifySame(Etc.makeDictsGrid(Etc.emptyDict, Dict[,]), Etc.emptyGrid)
   verifyNotSame(Etc.makeDictsGrid(["foo":"bar"], Dict[,]), Etc.emptyGrid)
   verifyDictEq(Etc.makeDictsGrid(["foo":"bar"], Dict[,]).meta, ["foo":"bar"])
 }

//////////////////////////////////////////////////////////////////////////
// DisCompare
//////////////////////////////////////////////////////////////////////////

  Void testCompareDis()
  {
    verifyCompareDis("",        "",        0)
    verifyCompareDis("z",       "A",       1)
    verifyCompareDis("Z",       "A",       1)
    verifyCompareDis("z4",      "A4",      1)
    verifyCompareDis("zx",      "Ax",      1)
    verifyCompareDis("Foo",     "",        1)
    verifyCompareDis("x9",      "x3",      1)
    verifyCompareDis("x19",     "x3",      1)
    verifyCompareDis("AHU-123", "AHU-9",   1)
    verifyCompareDis("ahu-019", "AHU-003", 1)
    verifyCompareDis("AHU-19",  "ahu-3",   1)
    verifyCompareDis("AHU",     "ahu",     0)
    verifyCompareDis("ahu 4",   "ahu",     1)
    verifyCompareDis("ahu 10",  "ahu 4",   1)
    verifyCompareDis("Fb 9",    "Fa 9",    1)
    verifyCompareDis("Fb 1",    "Fa 9",    1)
    verifyCompareDis("Fax 123", "Fa 123",  1)
    verifyCompareDis("Fx 123",  "Faa 123", 1)
    verifyCompareDis("x-2",     "x-1a",    1)
    verifyCompareDis("x-20",    "x-1a",    1)
    verifyCompareDis("x2",      "x13",     -1)
    verifyCompareDis("x",       "x13",     -1)
    verifyCompareDis("3",       "2",       1)
    verifyCompareDis("3",       "3",       0)

    verifyCompareDis("AHU 01",        "AHU 07", -1)
    verifyCompareDis("AHU 01 Fan",    "AHU 07", -1)
    verifyCompareDis("AHU 01 Fan 04", "AHU 07", -1)

    verifyCompareDisList(
      ["Chiller 2", "ChillerPlantAC2DOR", "CHWP4", "CHWP3", "CT2", "CT1", "Chiller 4", "Chiller 3", "Chiller 1"].sort |a,b| { Etc.compareDis(a,b) },
      ["Chiller 1", "Chiller 2", "Chiller 3", "Chiller 4", "ChillerPlantAC2DOR", "CHWP3", "CHWP4", "CT1", "CT2"])

    verifyCompareDisList(
       ["AHU 07", "AHU 07 Discharge Fan", "AHU 01 Return Fan", "AHU 04", "AHU 03 Return Fan",
        "AHU 04 Return Fan", "AHU 01 Discharge Fan 02","AHU 07 Return Fan", "AHU 01 Discharge Fan 01",
        "AHU 03 Discharge Fan", "AHU 04 Discharge Fan 01", "MAU 09", "AHU 02 Discharge Fan",
        "MAU 09 Discharge Fan", "AHU 01", "AHU 02", "AHU 04 Discharge Fan 02", "AHU 03"],
       ["AHU 01", "AHU 01 Discharge Fan 01", "AHU 01 Discharge Fan 02", "AHU 01 Return Fan",
        "AHU 02", "AHU 02 Discharge Fan",
        "AHU 03", "AHU 03 Discharge Fan", "AHU 03 Return Fan",
        "AHU 04", "AHU 04 Discharge Fan 01", "AHU 04 Discharge Fan 02", "AHU 04 Return Fan",
        "AHU 07", "AHU 07 Discharge Fan", "AHU 07 Return Fan",
        "MAU 09", "MAU 09 Discharge Fan"])
  }

  Void verifyCompareDis(Str a, Str b, Int expected)
  {
    x := Etc.compareDis(a, b)
    if (x < 0) x = -1; else if (x > 0) x = +1
    // sym := x == 0 ? "==" : (x == -1 ? "<" : ">")
    // echo("$a.toCode $sym $b.toCode")
    verifyEq(x, expected)

    x = Etc.compareDis(b, a)
    if (x < 0) x = +1; else if (x > 0) x = -1
    verifyEq(x, expected)
  }

  Void verifyCompareDisList(Str[] input, Str[] expected)
  {
    actual := input.dup.sort |a,b| { Etc.compareDis(a,b) }
    verifyEq(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// RelDis
//////////////////////////////////////////////////////////////////////////

  Void testRelDis()
  {
    verifyEq(Etc.relDis("Foo", "Bar"),     "Bar")
    verifyEq(Etc.relDis("Foo", "ab"),      "ab")
    verifyEq(Etc.relDis("Foo", "abcd"),    "abcd")
    verifyEq(Etc.relDis("Foo", "Foo"),     "Foo")
    verifyEq(Etc.relDis("Foo", "Foo Bar"), "Bar")
    verifyEq(Etc.relDis("Foo Floor", "Foo AHU"), "AHU")
    verifyEq(Etc.relDis("Foo Floor", "Foo AHU"), "AHU")
    verifyEq(Etc.relDis("Foo Floor", "Foobar"), "Foobar")
    verifyEq(Etc.relDis("Foo Bar Roo", "Foo Bar Roof Top"), "Roof Top")
    verifyEq(Etc.relDis("Foo Bar Roo", "Foo Bar   Roof Top"), "Roof Top")
    verifyEq(Etc.relDis("Foo Bar Roo", "Foo Bar : Roof Top"), "Roof Top")
    verifyEq(Etc.relDis("Foo Bar Roo", "Foo Bar - Roof Top"), "Roof Top")
    verifyEq(Etc.relDis("Foo Bar Roo", "Foo Bar \u2022 Roof Top"), "Roof Top")
  }

//////////////////////////////////////////////////////////////////////////
// ToDis
//////////////////////////////////////////////////////////////////////////

  Void testToDis()
  {
    id := Ref.gen

    verifyEq(Etc.emptyDict.dis, "")
    verifyEq(Etc.emptyDict.dis(null, "!"), "!")

    verifyToDis(["disMacro":Str<|$equipRef $navName|>, "equipRef":Ref("e", "RTU"),
                 "navName":"Fan"], "RTU Fan")
    verifyToDis(["disMacro":Str<|${navName}-${stage}|>, "navName":"Cool",
                 "stage":Number(3)], "Cool-3")
    verifyToDis(["disMacro":Str<|$<haystack::justNow>|>], "Just now")
    verifyToDis(["disMacro":Str<|$<haystack::justNow>|>, "dis":"X"], "X")
    verifyToDis(["disKey":"foo::bar"], "foo::bar")
    verifyToDis(["disKey":"haystack::foo"], "haystack::foo")
    verifyToDis(["disKey":"haystack::today"], "Today")
    verifyToDis(["dis":"X"], "X")
    verifyToDis(["id":id], id.dis)
  }

  Void verifyToDis(Obj? tags, Str expected)
  {
    verifyEq(Etc.makeDict(tags).dis, expected)
    verifyEq(Etc.makeDict(tags).dis, expected)
  }

//////////////////////////////////////////////////////////////////////////
// TsToDis
//////////////////////////////////////////////////////////////////////////

  Void testTsToDis()
  {
    now := DateTime.now
    yesterday := now.date.minus(1day).midnight
    twoDaysAgo := now.date.minus(2day).midnight
    fourDaysAgo := now.date.minus(4day).midnight
    sixDaysAgo := now.date.minus(6day).midnight
    jan1 := Date(now.year, Month.jan, 1).midnight
    dec31 := Date(now.year-1, Month.dec, 31).midnight
    jun7 := Date(2018, Month.jun, 7).midnight
    verifyTsToDis(now, null,            "")
    verifyTsToDis(now, now,             "Just now")
    verifyTsToDis(now, now-30sec,       "Just now")
    verifyTsToDis(now, now-5min,        (now-5min).time.toLocale)
    verifyTsToDis(now, now-5min,        (now-5min).time.toLocale)
    verifyTsToDis(now, yesterday,       "Yesterday 12:00AM")
    verifyTsToDis(now, yesterday+13hr,  "Yesterday 1:00PM")
    verifyTsToDis(now, twoDaysAgo,      "$twoDaysAgo.weekday.toLocale (2 days ago)")
    verifyTsToDis(now, fourDaysAgo,     "$fourDaysAgo.weekday.toLocale (4 days ago)")
    verifyTsToDis(now, sixDaysAgo,      sixDaysAgo.toLocale("WWW D MMM"))
    verifyTsToDis(now, jan1,            "$jan1.weekday.toLocale 1 Jan")
    verifyTsToDis(now, dec31,           "31 Dec $dec31.year")
    verifyTsToDis(now, jun7,            "7 Jun 2018")
  }

  Void verifyTsToDis(DateTime now, DateTime? ts, Str expected)
  {
    actual := Etc.tsToDis(ts, now)
    //if (ts != null) echo("-- $ts.weekday $ts.toLocale | $actual")
    verifyEq(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// SortCompare
//////////////////////////////////////////////////////////////////////////

  Void testSortCompare()
  {
    verifySortCompare(null, null, 0)
    verifySortCompare(null, "foo", -1)
    verifySortCompare("foo", null, +1)

    verifySortCompare("Alpha", "Beta", -1)
    verifySortCompare("Alpha", "beta", -1)
    verifySortCompare("alpha", "Beta", -1)

    verifySortCompare("s", true, -1)
    verifySortCompare("s", n(123), +1)
    verifySortCompare("s", Marker.val, +1)

    verifySortCompare(Ref("a"), Ref("b"), -1)
    verifySortCompare(Ref("a", "Z"), Ref("b", "A"), +1)

    verifySortCompare(n(2), n(3), -1)
    verifySortCompare(n(2, "kW"), n(3, "ft"), -1)
    verifySortCompare(n(20, "hr"), n(3, "ft"), +1)
    verifySortCompare(n(2, "hr"), n(3, "min"), +1)
  }

  Void verifySortCompare(Obj? a, Obj? b, Int expected)
  {
    // echo("-- $a <=> $b  >> " + Etc.sortCompare(a, b) + " ?= $expected")
    verifyEq(Etc.sortCompare(a, b), expected)
  }

//////////////////////////////////////////////////////////////////////////
// Macros
//////////////////////////////////////////////////////////////////////////

  Void testMacro()
  {
    scope := Etc.makeDict([
       "equipRef":Ref("e", "RTU-2"),
       "siteRef":Ref("s", "Store"),
       "navName":"Cool", "stage":Number(2),
       "a":"Alpha",
       "a_x":"AlphaX!",
       "a_12":"Alpha12!",
       "b":"Beta"])

    // no expr
    verifyMacro(Str<||>, scope, Str<||>)
    verifyMacro(Str<|?|>, scope, Str<|?|>)
    verifyMacro(Str<|hello|>, scope, Str<|hello|>)
    verifyMacro(Str<|{}|>, scope, Str<|{}|>)

    // simple expressions
    verifyMacro(Str<|$siteRef|>, scope, Str<|Store|>, ["siteRef"])
    verifyMacro(Str<|$siteRef!|>, scope, Str<|Store!|>, ["siteRef"])
    verifyMacro(Str<|$equipRef $navName|>, scope, Str<|RTU-2 Cool|>, ["equipRef", "navName"])
    verifyMacro(Str<|$navName$stage|>, scope, Str<|Cool2|>, ["navName", "stage"])
    verifyMacro(Str<|$navName#$stage|>, scope, Str<|Cool#2|>, ["navName", "stage"])
    verifyMacro(Str<|$|>, scope, Str<|$|>)
    verifyMacro(Str<|$@|>, scope, Str<|$@|>)
    verifyMacro(Str<|$a,$a,$b,$a,$b|>, scope, Str<|Alpha,Alpha,Beta,Alpha,Beta|>, ["a", "b"])
    verifyMacro(Str<|$a_x|>, scope, Str<|AlphaX!|>,   ["a_x"])
    verifyMacro(Str<|$a_12|>, scope, Str<|Alpha12!|>, ["a_12"])
    verifyMacro(Str<|$a.x|>, scope, Str<|Alpha.x|>,   ["a"])
    verifyMacro(Str<|$a-x|>, scope, Str<|Alpha-x|>,   ["a"])
    verifyMacro(Str<|$a->x|>, scope, Str<|Alpha->x|>, ["a"])

    // brace expressions
    verifyMacro(Str<|${siteRef}|>, scope, Str<|Store|>, ["siteRef"])
    verifyMacro(Str<|${siteRef}!|>, scope, Str<|Store!|>, ["siteRef"])
    verifyMacro(Str<|${navName}${stage}|>, scope, Str<|Cool2|>, ["navName", "stage"])
    verifyMacro(Str<|${navName}-$stage|>, scope, Str<|Cool-2|>, ["navName", "stage"])
    verifyMacro(Str<|${navName}-${stage}|>, scope, Str<|Cool-2|>, ["navName", "stage"])
    verifyMacro(Str<|${|>, scope, Str<|${|>)
    verifyMacro(Str<|${x|>, scope, Str<|${x|>)
    verifyMacro(Str<|${x-|>, scope, Str<|${x-|>)
    verifyMacro(Str<|${}|>, scope, Str<|${}|>)
    verifyMacro(Str<|${not good}|>, scope, Str<|${not good}|>, ["not good"])

    // locale expressions
    verifyMacro(Str<|$<haystack::justNow>|>,  scope, Str<|Just now|>)
    verifyMacro(Str<|$<haystack::justNow>-$stage|>,  scope, Str<|Just now-2|>, ["stage"])
    verifyMacro(Str<|$<haystack::justNow>!|>, scope, Str<|Just now!|>)
    verifyMacro(Str<|$<haystack::justNow|>,   scope, Str<|$<haystack::justNow|>)
    verifyMacro(Str<|$<bad::name>|>,  scope, Str<|$<bad::name>|>)
    verifyMacro(Str<|$<haystack::bad>|>,   scope, Str<|$<haystack::bad>|>)
  }

  Void verifyMacro(Str pattern, Dict scope, Str expected, Str[] vars := Str[,])
  {
    // echo("#### $pattern")
    actual := Etc.macro(pattern, scope)
    // echo("     $actual ?= $expected")
    // echo("     " + Etc.macroVars(pattern))
    verifyEq(actual, expected)
    verifyEq(Etc.macroVars(pattern), vars)
  }

//////////////////////////////////////////////////////////////////////////
// Dict Hash Key
//////////////////////////////////////////////////////////////////////////

  Void testDictHashKey()
  {
    a := Etc.makeDict(["a":Number(3)])
    b := Etc.makeDict(["b":Number(3)])
    c := Etc.makeDict(["b":Number(4)])
    d := Etc.makeDict(["b":"x"])
    e := Etc.makeDict(["b":"x", "c":"y"])
    f := Etc.makeDict(["b":Date.today, "c":null])
    dicts := [Etc.emptyDict, a, b, c, d, e, f]

    dicts.each |dictI, i|
    {
      dicts.each |dictJ, j|
      {
        verifyDictHashKey(dictI, dictJ, i == j)
      }
    }

    verifyDictHashKey(d, Etc.makeDict(["b":"x", "null": null]), true)

    Dict x := Etc.makeDict3("a", Number(1), "b", Number(2), "c", Number(3))
    Dict y := Etc.makeDict3("c", Number(3), "b", Number(2), "a", Number(1))
    verifyDictHashKey(x, y, true)

    /*
    x = Etc.makeDict(["dis":"Weekly schedule", "start":Time(3, 0), "end":Time(4, 30), "val":true])
    y = Etc.makeDict(["dis":"Weekly schedule", "start":Time(3, 0), "end":Time(4, 30), "val":false])
    verifyDictHashKey(x, y, false)
    */
  }

  Void verifyDictHashKey(Dict ad, Dict bd, Bool eq)
  {
    a := Etc.dictHashKey(ad)
    b := Etc.dictHashKey(bd)
    // echo("=== $a.hash.toHex $a")
    // echo("    $b.hash.toHex $b")
    if (eq)
    {
      verifyEq(a.hash, b.hash)
      verifyEq(a, b)
    }
    else
    {
      verifyNotEq(a.hash, b.hash)
      verifyNotEq(a, b)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Grid Flatten
//////////////////////////////////////////////////////////////////////////

  Void testGridFlatten()
  {
    a := ZincReader(
      Str<|ver:"3.0"
           a, b dis:"Beta", c, d
           1, 2, 3, 4
           5, 6, 7, 8
           |>.in).readGrid

    b := ZincReader(
      Str<|ver:"3.0"
           b dis:"Nope", c dis:"Charlie" charlie, e
           9, 10, 11
           12, 13, 14
           |>.in).readGrid

    c := ZincReader(
      Str<|ver:"3.0"
           a foo, f
           N, "x"
           "y", N
           |>.in).readGrid

    ab := ZincReader(
      Str<|ver:"3.0"
           a, b dis:"Beta", c dis:"Charlie" charlie, d, e
           1, 2, 3, 4, N
           5, 6, 7, 8, N
           N, 9, 10, N, 11
           N, 12, 13, N, 14
           |>.in).readGrid

    abc := ZincReader(
      Str<|ver:"3.0"
           a foo, b dis:"Beta", c dis:"Charlie" charlie, d, e, f
           1, 2, 3, 4, N, N
           5, 6, 7, 8, N, N
           N, 9, 10, N, 11, N
           N, 12, 13, N, 14, N
           N, N,  N, N, N, "x"
           "y", N,  N, N, N, N
           |>.in).readGrid

    verifySame(Etc.gridFlatten(Grid[,]), Etc.emptyGrid)
    verifySame(Etc.gridFlatten([a]), a)
    verifySame(Etc.gridFlatten([b]), b)
    verifyGridEq(Etc.gridFlatten([a, b]), ab)
    verifyGridEq(Etc.gridFlatten([a, b, c]), abc)
  }


}