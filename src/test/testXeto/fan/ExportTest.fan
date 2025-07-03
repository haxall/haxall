//
// Copyright (c) 2024, Brian Frank
// All Rights Reserved
//
// History:
//   31 Oct 2024  Brian Frank  Halloween!
//

using util
using xeto
using xetoEnv
using haystack

**
** ExportTest
**
@Js
class ExportTest : AbstractXetoTest
{
  Void test()
  {
    ns := createNamespace(["hx.test.xeto"])
    def := Etc.dict0
    eff := Etc.dict1("effective", m)

    lib := ns.lib("hx.test.xeto")
    depends := lib.depends.map |x| { Etc.dict3("lib", x.name, "versions", x.versions.toStr, "spec", Ref("sys::LibDepend")) }
    verifyExport(ns, def, "lib:hx.test.xeto", ["id":lib.id, "version":lib.version.toStr,
      "doc":lib->doc, "depends": depends, "spec":Ref("sys::Lib"), "categories":Obj?["haxall"],
      "org":Etc.dict3("dis", "Haxall", "uri", `https://haxall.io/`, "spec", Ref("sys::LibOrg"))
    ])

    /*
    // Test spec
    Alpha : Dict {
    }
    */
    verifyExport(ns, def, "Alpha", ["base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "doc":"Test spec"])

    /*
    // A
    A: Dict <q: Date "2024-01-01", foo:"A", bar:"A"> {
      x: Str
    }
    */
    verifyExport(ns, def, "A", ["base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "doc":"A",
       "q":Date("2024-01-01"), "foo":"A", "bar":"A",
       "slots":Etc.makeDict([
          "x": Etc.makeDict(
            ["id":Ref("hx.test.xeto::A.x"), "type":Ref("sys::Str"),
            "spec":Ref("sys::Spec"), "doc":"x slot"])
       ])
     ])

    /*
    own
    C : A {
      z: Str
    }
    */
    verifyExport(ns, def, "C", ["base":Ref("hx.test.xeto::A"), "spec":Ref("sys::Spec"),
       "slots":Etc.makeDict([
          "z": Etc.makeDict(
            ["id":Ref("hx.test.xeto::C.z"), "type":Ref("sys::Str"),
            "spec":Ref("sys::Spec")])
       ])
     ])

    /*
    effective
    C : A {
      z: Str
    }
    */
    verifyExport(ns, eff, "C", ["base":Ref("hx.test.xeto::A"), "spec":Ref("sys::Spec"), "doc":"A",
       "q":Date("2024-01-01"), "foo":"A", "bar":"A",
       "slots":Etc.makeDict([
          "x": Etc.makeDict(
            ["id":Ref("hx.test.xeto::A.x"), "type":Ref("sys::Str"),
            "spec":Ref("sys::Spec"), "doc":"x slot", "val":""]),
          "z": Etc.makeDict(
            ["id":Ref("hx.test.xeto::C.z"), "type":Ref("sys::Str"),
            "spec":Ref("sys::Spec"), "val":"", "doc":"Unicode string of characters"])
       ])
     ])

    /*
    // Equip with points
    EqA: Equip {
      points: {
        a: ZoneCo2Sensor
        b: ZoneCo2Sensor { foo }
      }
    }
    */
    verifyExport(ns, def, "EqA", ["base":Ref("ph::Equip"), "spec":Ref("sys::Spec"), "doc":"Equip with *points*",
       "slots":Etc.makeDict([
          "points": Etc.makeDict([
             "id":Ref("hx.test.xeto::EqA.points"),
             "type":Ref("sys::Query"),
             "spec":Ref("sys::Spec"),
             "slots": Etc.makeDict([
               "a": Etc.makeDict([
                 "id":Ref("hx.test.xeto::EqA.points.a"),
                 "type":Ref("ph.points::ZoneCo2Sensor"),
                 "spec":Ref("sys::Spec")
               ]),
               "b": Etc.makeDict([
                 "id":Ref("hx.test.xeto::EqA.points.b"),
                 "type":Ref("ph.points::ZoneCo2Sensor"),
                 "spec":Ref("sys::Spec"),
                 "slots": Etc.makeDict([
                    "foo": Etc.makeDict([
                      "id":Ref("hx.test.xeto::EqA.points.b.foo"),
                      "spec":Ref("sys::Spec"),
                      "type":Ref("sys::Str"),
                      "val":"!",
                   ])
                 ])
               ])
             ])
          ])
       ])
    ])

    // instance - simple
    verifyExport(ns, def, "test-b", ["beta":m])

    // instance - nested dicts no id
    verifyExport(ns, def, "toolbar1", ["save":Etc.dict1("text","Save"), "exit":Etc.dict1("text","Exit")])

    // instance - nested instances with id
    g := gridExport(ns, def)
    verifyNull(g.find |r| { r["id"]?.toStr == "hx.test.xeto::save" })
    verifyNull(g.find |r| { r["id"]?.toStr == "hx.test.xeto::exit" })
    verifyNotNull(g.find |r| { r["id"]?.toStr == "hx.test.xeto::toolbar1" })
    verifyNotNull(g.find |r| { r["id"]?.toStr == "hx.test.xeto::toolbar2" })
    verifyExport(ns, def, "toolbar2", [
      "save":Etc.dict2("id", Ref("hx.test.xeto::save"), "text", "Save"),
      "exit":Etc.dict2("id", Ref("hx.test.xeto::exit"), "text", "Exit"),
      ])

    // instance - toHaystack coercion
    verifyExport(ns, def, "coerce", [
      "int":n(1), "float":n(2), "dur":n(3, "min"), "num":n(4, "kW"),
      "date":Date("2024-10-31"), "version":"1.2.3",
      "list":Obj?[n(4)], "dict":Etc.dict1("x", n(4))
      ])
  }

  Void verifyExport(LibNamespace ns, Dict opts, Str relId, Str:Obj expect)
  {
    verifyGridExport(ns, opts, relId, expect)
    verifyJsonExport(ns, opts, relId, expect)
  }

  private Void verifyJsonExport(LibNamespace ns, Dict opts, Str relId, Str:Obj expect)
  {
    if (relId.startsWith("lib:"))
    {
      relId = "pragma"
      expect.remove("spec")
      expect.remove("id")
    }
    else
    {
      expect["id"] = "hx.test.xeto::$relId"
    }

    doc := jsonExport(ns, opts)
    lib := (Str:Obj?)doc.getChecked("hx.test.xeto")
    a := (Str:Obj?)lib.getChecked(relId)
    b := (Str:Obj?)toJson(expect)
    if (a == b) return verifyEq(a, b)

    echo("FAIL: verifyJsonExport")
    echo(JsonOutStream.prettyPrintToStr(a))
    echo("Fields:")
    printDiff(a, b)
    fail
  }

  private Void printDiff(Str:Obj? a, Str:Obj? b, Str path := "")
  {
    a.each |av, n|
    {
      bv := b[n]
      if (av != bv)
      {
        if (av is Map && bv is Map)
        {
          echo(" $path/$n maps not equal")
          printDiff(av, bv, "$path/$n")
        }
        else
          echo("  $path/$n: $av [$av.typeof] != $bv [${bv?.typeof}]")
      }
    }
    b.each |bv, n|
    {
      av := a[n]
      if (av == null) echo(" $path/$n: null != $bv [${bv?.typeof}]")
    }
  }

  private Obj toJson(Obj v)
  {
    if (v is Dict) v = Etc.dictToMap(v)
    if (v is List) return ((List)v).map |x| { toJson(x) }
    if (v is Map) return ((Map)v).map |x| { toJson(x) }
    if (v is Marker) return "\u2713"
    return v.toStr
  }

  private Void verifyGridExport(LibNamespace ns, Dict opts, Str relId, Str:Obj expect)
  {
    grid := gridExport(ns, opts)
    id := Ref(relId.contains(":") ? relId : "hx.test.xeto::$relId")
    expect = expect.dup.set("id", id)
    row := grid.find |r| { r["id"] == id } ?: throw Err("missing: $id")
    // echo; echo(">>>>"); row.each |v, n| { echo("$n = $v [$v.typeof]") }
    verifyDictEq(row, expect)
    return row
  }

  private Str:Obj? jsonExport(LibNamespace ns, Dict opts)
  {
    buf := Buf()
    e := JsonExporter(ns, buf.out, opts)
    e.start.lib(ns.lib("hx.test.xeto")).end
    str := buf.flip.readAllStr
    doc := JsonInStream(str.in).readJson
    return doc
  }

  private Grid gridExport(LibNamespace ns, Dict opts)
  {
    trio := defs.filetype("trio")
    e := GridExporter(ns, Buf().out, opts, trio)
    e.lib(ns.lib("hx.test.xeto"))
    return e.toGrid
  }
}

