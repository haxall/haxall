//
// Copyright (c) 2024, Brian Frank
// All Rights Reserved
//
// History:
//   31 Oct 2024  Brian Frank  Halloween!
//

using xeto
using xetoEnv
using haystack
using haystack::Dict
using haystack::Ref

**
** ExportTest
**
@Js
class ExportTest : AbstractXetoTest
{
  Void testGrid()
  {
    ns := createNamespace(["hx.test.xeto"])
    def := Etc.dict0
    eff := Etc.dict1("effective", m)

    /*
    // Test spec
    Alpha : Dict {
    }
    */
    verifyGridExport(ns, def, "Alpha", ["base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "doc":"Test spec"])

    /*
    // A
    A: Dict <q: Date "2024-01-01", foo:"A", bar:"A"> {
      x: Str
    }
    */
    verifyGridExport(ns, def, "A", ["base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "doc":"A",
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
    verifyGridExport(ns, def, "C", ["base":Ref("hx.test.xeto::A"), "spec":Ref("sys::Spec"),
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
    verifyGridExport(ns, eff, "C", ["base":Ref("hx.test.xeto::A"), "spec":Ref("sys::Spec"), "doc":"A",
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
    /*
    verifyGridExport(ns, def, "EqA", ["base":Ref("ph::Equip"), "spec":Ref("sys::Spec"), "doc":"Equip with points",
       "slots":Etc.makeDict([
          "points": Etc.makeDict([,
          ])
       ])
    ])
    */

    // instance - simple
    verifyGridExport(ns, def, "test-b", ["beta":m])

    // instance - nested dicts no id
   verifyGridExport(ns, def, "toolbar1", ["save":Etc.dict1("text","Save"), "exit":Etc.dict1("text","Exit")])

    // instance - nested instances with id
    g := gridExport(ns, def)
    verifyNull(g.find |r| { r["id"]?.toStr == "hx.test.xeto::save" })
    verifyNull(g.find |r| { r["id"]?.toStr == "hx.test.xeto::exit" })
    verifyNotNull(g.find |r| { r["id"]?.toStr == "hx.test.xeto::toolbar1" })
    verifyNotNull(g.find |r| { r["id"]?.toStr == "hx.test.xeto::toolbar2" })
    verifyGridExport(ns, def, "toolbar2", [
      "save":Etc.dict2("id", Ref("hx.test.xeto::save"), "text", "Save"),
      "exit":Etc.dict2("id", Ref("hx.test.xeto::exit"), "text", "Exit"),
      ])
  }

  Grid gridExport(LibNamespace ns, Dict opts)
  {
    trio := this.ns.filetype("trio")
    e := GridExporter(ns, Buf().out, opts, trio)
    e.lib(ns.lib("hx.test.xeto"))
    return e.toGrid
  }

  Dict verifyGridExport(LibNamespace ns, Dict opts, Str relId, Str:Obj expect)
  {
     grid := gridExport(ns, opts)
     id := Ref("hx.test.xeto::$relId")
     expect = expect.dup.set("id", id)
     row := grid.find |r| { r["id"] == id } ?: throw Err("missing: $id")
//echo(">>> $row")
     verifyDictEq(row, expect)
     return row
   }
}

