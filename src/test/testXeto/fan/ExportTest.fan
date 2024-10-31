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

    // instance - nested dicts
   verifyGridExport(ns, def, "toolbar1", ["save":Etc.dict1("text","Save"), "exit":Etc.dict1("text","Exit")])

    // instance - nested instances uses ref indirection
    save := verifyGridExport(ns, def, "save", ["text":"Save"])
    exit := verifyGridExport(ns, def, "exit", ["text":"Exit"])
    verifyGridExport(ns, def, "toolbar2", ["save":save.id, "exit":exit.id])
  }

  Dict verifyGridExport(LibNamespace ns, Dict opts, Str relId, Str:Obj expect)
  {
    trio := this.ns.filetype("trio")
    e := GridExporter(ns, Buf().out, opts, trio)
    e.lib(ns.lib("hx.test.xeto"))
    grid := e.toGrid

     id := Ref("hx.test.xeto::$relId")
     expect = expect.dup.set("id", id)
     row := grid.find |r| { r["id"] == id } ?: throw Err("missing: $id")
     // echo(">>> $row")
     verifyDictEq(row, expect)
     return row
   }
}

