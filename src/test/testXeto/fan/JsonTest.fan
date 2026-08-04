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

  ** box=none is lossy exactly where the plain form cannot be recovered;
  ** auto and all recover it.  The default mode is none.
  Void testBoxModes()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyEq(XetoUtil.optBox(Etc.dict0), JsonBoxMode.none)

    // an untyped dict whose values have no recoverable plain form
    dict := Etc.dict4(
      "mark", m,
      "ref",  Ref("abc"),
      "num",  n(90),
      "date", Date.fromStr("2024-11-26"))

    verifyDictEq(roundTrip(ns, dict, boxNone), Etc.dict4(
      "mark", "✓",
      "ref",  "abc",
      "num",  90,
      "date", "2024-11-26"))

    verifyDictEq(roundTrip(ns, dict, boxAuto), dict)
    verifyDictEq(roundTrip(ns, dict, boxAll),  dict)

    // a Bool needs no box even under auto, but all boxes it anyway
    verifyEq(toJson(ns, true, boxAuto), "true")
    verifyEq(toJson(ns, true, boxAll),
      Str<|{
             "val":"true",
             "spec":"sys::Bool"
           }|>)

    // the box wire form: val first, then spec, both plain strings
    verifyEq(toJson(ns, Etc.dict1("a", m), boxAll),
      Str<|{
             "a":{
               "val":"✓",
               "spec":"sys::Marker"
             }
           }|>)
  }

  ** The 'plainRoundTrips' predicate drives box=auto, so it must never claim a
  ** plain form survives when it does not.  It is allowed to be conservative
  ** in the other direction.
  Void testPlainRoundTrips()
  {
    ns := createNamespace(["hx.test.xeto"])
    specs := XetoJsonSpec(ns)

    vals := Obj[
      true, 123, 72.0f, Float.nan, Float.posInf, Float.negInf,
      n(90), n(3.4f), n(90, "kW"), Number.nan,
      "abc", "✓", m, None.val, NA.val,
      Ref("abc"), `file.txt`,
      Date.fromStr("2024-11-26"), Time.fromStr("14:30:00"),
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York"),
      Version.fromStr("4.0.9"), TimeZone.fromStr("Chicago"),
    ]

    expects := Spec?[
      null,
      ns.spec("sys::Bool"),
      ns.spec("sys::Int"),
      ns.spec("sys::Float"),
      ns.spec("sys::Number"),
      ns.spec("sys::Str"),
      ns.spec("sys::Marker"),
      ns.spec("sys::Ref"),
      ns.spec("sys::Date"),
      ns.spec("sys::Uri"),
      ns.spec("sys::Duration"),
      ns.spec("sys::Dict"),
    ]

    vals.each |val|
    {
      expects.each |expect|
      {
        if (!specs.plainRoundTrips(val, expect)) return
        verifyEq(plainSurvives(ns, val, expect), true,
          "plainRoundTrips claimed $val [$val.typeof] survives at $expect")
      }
    }
  }

  ** Does the plain encoding of val actually decode back to val in a position
  ** whose expected spec is 'spec'?  Compares type and string form so that
  ** NaN, which is never equal to itself, still compares.
  private Bool plainSurvives(MNamespace ns, Obj val, Spec? spec)
  {
    try
    {
      x := roundTrip(ns, val, boxNone, spec)
      return x != null && x.typeof === val.typeof && x.toStr == val.toStr
    }
    catch
      return false
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

  private Str toJson(MNamespace ns, Obj? x, Dict? opts := null, Spec? spec := null)
  {
    buf := Buf()
    XetoJsonWriter(ns, buf.out, spec, Etc.dictSet(opts, "pretty", m)).writeVal(x)
    str := buf.flip.readAllStr
    //echo("-----------------------------------------")
    //echo(str)
    return str
  }

  ** Write then read back through the same position spec
  private Obj? roundTrip(MNamespace ns, Obj? x, Dict? opts := null, Spec? spec := null)
  {
    XetoJsonReader(ns, toJson(ns, x, opts, spec).in, spec).readVal
  }

  private static const Dict haystackOpts := Etc.dict1("haystack", m)
  private static const Dict boxNone := Etc.dict1("box", "none")
  private static const Dict boxAuto := Etc.dict1("box", "auto")
  private static const Dict boxAll  := Etc.dict1("box", "all")
}

