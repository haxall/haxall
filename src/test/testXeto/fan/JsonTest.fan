//
// Copyright (c) 2026, Brian Frank
// All Rights Reserved
//
// History:
//   9 Jan 2026  Mike Jarmy
//

using util
using xeto
using xetom
using haystack

**
** JsonTest
**
@Js
class JsonTest : AbstractXetoTest
{
  Void testHaystack()
  {
    ns := createNamespace(["hx.test.xeto"])
    opts := Etc.dict1("haystack", m)

    verifyHaystack(ns, null, null)
    verifyHaystack(ns, true, true)
    verifyHaystack(ns, "abc", "abc")
    verifyHaystack(ns, n(1), n(1))
    verifyHaystack(ns, 2, n(2))
    verifyHaystack(ns, 3.4f, n(3.4f))

    verifyHaystack(ns,
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York"),
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York"),
      ns.spec("sys::DateTime"))

    verifyHaystack(ns,
      [null, "true", 1, n(2)],
      [null, "true", n(1), n(2)])

    verifyHaystack(ns,
      Etc.dict4("a", true, "b", "xyz", "c", n(1), "d", 2),
      Etc.dict4("a", true, "b", "xyz", "c", n(1), "d", n(2)))
  }

  Void test()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyRoundTrip(ns,
      ns.instance("hx.test.xeto::jsonScalarsA"),
      ns.spec("hx.test.xeto::JsonScalars"))

    dict := ns.instance("hx.test.xeto::jsonNestA")

    verifyRoundTrip(ns,
      ns.instance("hx.test.xeto::jsonNestA"),
      ns.spec("hx.test.xeto::JsonNest"))
  }

  Void testPretty()
  {
    verifyEq(
      toJson(
        Etc.dict3(
          "a", 1,
          "b", ["a", 1, [Etc.dict2("f", 4, "g", 5), 3, ["b", 4]]],
          "c", Etc.dict2(
            "d", 3,
            "e", Etc.dict2("f", 4, "g", 5)))),
      Str<|{
             "a":1,
             "b":[
               "a",
               1,
               [
                 {
                   "f":4,
                   "g":5
                 },
                 3,
                 [
                   "b",
                   4
                 ]
               ]
             ],
             "c":{
               "d":3,
               "e":{
                 "f":4,
                 "g":5
               }
             }
           }|>)

    gb := GridBuilder()
    gb.setMeta(Etc.dict1("foo", "quux"))
    gb.addCol("a").addCol("b", Etc.dict1("dis", "B"))
    gb.addDictRow(Etc.dict2("a", 0, "b", "x"))
    gb.addDictRow(Etc.dict2("a", 1, "b", "y"))
    grid := gb.toGrid

    verifyEq(
      toJson(grid),
      Str<|{
             "spec":"sys::Grid",
             "meta":{
               "#grid":{
                 "foo":"quux"
               },
               "b":{
                 "dis":"B"
               }
             },
             "rows":[
               {
                 "a":0,
                 "b":"x"
               },
               {
                 "a":1,
                 "b":"y"
               }
             ]
           }|>)
  }

  Void testGrid()
  {
    ns := createNamespace(["hx.test.xeto"])

    gb := GridBuilder()
    gb.addCol("a").addCol("b")
    gb.addDictRow(Etc.dict2("a", 0, "b", "x"))
    gb.addDictRow(Etc.dict2("a", 1, "b", "y"))
    grid := gb.toGrid
    verifyRoundTrip(ns, grid)

    gb = GridBuilder()
    gb.setMeta(Etc.dict1("foo", "quux"))
    gb.addCol("a").addCol("b", Etc.dict1("dis", "B"))
    gb.addDictRow(Etc.dict2("a", 0, "b", "x"))
    gb.addDictRow(Etc.dict2("a", 1, "b", "y"))
    grid = gb.toGrid
    verifyRoundTrip(ns, grid)
  }

  private Void verifyHaystack(
    MNamespace ns,
    Obj? orig,
    Obj? expect,
    Spec? spec := null)
  {
    str := toJson(orig)

    read := XetoJsonReader(ns, str.in, spec, haystackOpts).readVal
    if (orig is Dict)
      verifyDictEq(read, expect)
    else
      verifyEq(read, expect)
  }

  private Void verifyRoundTrip(
    MNamespace ns,
    Obj? a,
    Spec? spec := null,
    Dict? opts := null)
  {
    //echo("=============================================================")
    str := toJson(a)
    b := XetoJsonReader(ns, str.in, spec, opts).readVal

    if (a is Dict)
      verifyDictEq(a, b)
    else if (a is Grid)
      verifyGridEq(a, b)
    else
      verifyEq(a, b)
  }

  private Str toJson(Obj? x)
  {
    buf := Buf()
    XetoJsonWriter(buf.out, Etc.dict1("pretty", m)).writeVal(x)
    str := buf.flip.readAllStr
    //echo("-----------------------------------------")
    //echo(str)
    return str
  }

  private static const Dict haystackOpts := Etc.dict1("haystack", m)
}

