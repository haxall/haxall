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

    // an untyped position never decodes by what the string looks like, so a
    // plain marker does not survive; box=auto is the lossless encoding
    verifyHaystack(ns, m, "✓")
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
      Etc.dict5("z", m, "a", true, "b", "xyz", "c", n(1), "d", 2),
      Etc.dict5("z", "✓", "a", true, "b", "xyz", "c", n(1), "d", n(2)))
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

  ** A list spec is not required to declare 'of'.  Without it the items are
  ** decoded untyped rather than raising "Missing 'of' meta".
  Void testListWithoutOf()
  {
    ns := createNamespace(["hx.test.xeto"])

    listSpec := ns.spec("sys::List")
    verifyEq(XetoJsonReader(ns, "[\"a\", \"b\"]".in, listSpec).readVal,
             Obj["a", "b"])

    // a null item makes the list nullable; the codec does not enforce the
    // 'of' nullability, which is left to Namespace.validate
    verifyEq(XetoJsonReader(ns, "[\"a\", null]".in, listSpec).readVal,
             Obj?["a", null])
    verifyEq(XetoJsonReader(ns, "[]".in, listSpec).readVal, Obj[,])

    // an 'of' slot still types its items
    slot := ns.spec("hx.test.xeto::JsonNest").slot("dates")
    verifyEq(XetoJsonReader(ns, "[\"2024-11-26\"]".in, slot).readVal,
             Obj[Date("2024-11-26")])
    verifyEq(XetoJsonReader(ns, "[\"2024-11-26\", null]".in, slot).readVal,
             Obj?[Date("2024-11-26"), null])
  }

  Void testPretty()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyEq(
      toJson(ns,
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
      toJson(ns, grid),
      Str<|{
             "spec":"sys::Grid",
             "meta":{
               "foo":"quux"
             },
             "cols":[
               {
                 "name":"a"
               },
               {
                 "name":"b",
                 "meta":{
                   "dis":"B"
                 }
               }
             ],
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
    grid := gb.toGrid
    verifyRoundTrip(ns, grid)

    gb = GridBuilder()
    gb.addCol("a").addCol("b")
    gb.addDictRow(Etc.dict2("a", 0, "b", "x"))
    gb.addDictRow(Etc.dict2("a", 1, "b", "y"))
    grid = gb.toGrid
    verifyRoundTrip(ns, grid)

    // grid meta is untyped, so a marker there would decode as Str "✓"
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
    str := toJson(ns, orig)

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
    str := toJson(ns, a)
    b := XetoJsonReader(ns, str.in, spec, opts).readVal

    if (a is Dict)
      verifyDictEq(a, b)
    else if (a is Grid)
      verifyGridEq(a, b)
    else
      verifyEq(a, b)
  }

  private Str toJson(MNamespace ns, Obj? x)
  {
    buf := Buf()
    XetoJsonWriter(ns, buf.out, Etc.dict1("pretty", m)).writeVal(x)
    str := buf.flip.readAllStr
    //echo("-----------------------------------------")
    //echo(str)
    return str
  }

  private static const Dict haystackOpts := Etc.dict1("haystack", m)
}

