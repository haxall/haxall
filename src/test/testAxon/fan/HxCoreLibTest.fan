//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Dec 2021  Brian Frank   Creation
//

using xeto
using haystack
using axon
using hx

**
** HxCoreLibTest extends CoreLib tests for tests which use hx runtime.
** These tests do not run in JavaScript though
**
class HxCoreLibTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Defs
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testDefs()
  {
    verifyDefsInclude("defs()", ["elec", "elec-meter", "func:now"], [,])
    verifyDefsInclude("terms()", ["elec", "elec-meter"], ["func:now"])
    verifyDefsInclude("tags()", ["elec"], ["elec-meter", "func:now"])
    verifyDefsInclude("conjuncts()", ["elec-meter"], ["elec", "func:now"])
    verifyDefsInclude("libs()", ["lib:ph", "lib:hx"], ["elec", "elec-meter", "func:now"])

    verifyDefsEq("supertypes(^site)", ["geoPlace", "entity"])
    verifyDefsEq("inheritance(^site)", ["geoPlace", "entity", "marker", "site"])
    verifyDefsEq("inheritance(^ahu)", ["marker", "entity", "equip", "airHandlingEquip", "ahu", "air-output", "output", "elec-input", "input"])
    verifyDefsInclude("subtypes(^equip)", ["airHandlingEquip", "conduit", "chiller"], ["ahu", "duct"])
    verifyEq(eval("hasSubtypes(^equip)"), true)
    verifyEq(eval("hasSubtypes(^mau)"), false)

    verifyDefsInclude("associations(^site, ^tags)", ["id", "dis", "geoAddr", "geoCountry", "area"], ["unit"])

    verifyDefsEq("""reflect({chilled, water})""", ["chilled", "water", "chilled-water"])

    verifyDictsEq(eval("protos({equip})"), [["equip":m], ["point":m]])
  }

  Void verifyDefsEq(Str expr, Str[] syms)
  {
    g := (Def[])eval(expr)
    verifyEq(g.dup.sort.map |x->Str| { x.symbol.toStr }, syms.sort)
  }

  Void verifyDefsInclude(Str expr, Str[] has, Str[] missing)
  {
    g := (Def[])eval(expr)

    has.each |name|
    {
      row := g.find |r| { r->def.toStr == name }
      verifyNotNull(row, name)
      verifyDictEq(row, proj.defs.def(name))
    }

    missing.each |name|
    {
      row := g.find |r| { r->def.toStr == name }
      verifyNull(row, name)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Funcs Tests
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testFunc()
  {
    x := addFunc("x", "(a, b: true) => a + b", ["admin":Marker.val, "doc":"x hi!"])
    y := addFunc("y", "(a: 1, b: 1+2) => a + b", ["doc":"y hi!"])

    // func
    verifyEval("""func("y")""", normRecFunc(y))
    verifyEval("""func(y)""", normRecFunc(y))
    verifyEval("""func("map")->qname""", "axon::map")
    verifyEval("""func("badFuncNotFound", false)""", null)
    verifyEvalErr("""func("badFuncNotFound")""", UnknownFuncErr#)

    // funcs
    verifyEval("""funcs(admin).find(x => x->qname == "proj::x")""", normRecFunc(x))
    verifyEval("""funcs(not admin).find(x => x->qname == "proj::x")""", null)
    verifyEval("""funcs().findAll(x => x->qname == "axon::now").size""", n(1))
    verifyEval("""funcs(qname == "proj::x").first""", normRecFunc(x))

    // verify funcs() doesn't include nodoc
    verifyEval("""funcs().find(x => x->qname=="axon::dump")""", null)
    verifyEval("""funcs(admin).find(x => x->qname=="axon::dump")""", null)

    // isFunc
    verifyEval("isFunc(x)",     true)
    verifyEval("isFunc(()=>3)", true)
    verifyEval("isFunc(3)",     false)
  }

  @HxTestProj
  Void testCurFunc()
  {
    x := addFunc("x", "() => curFunc()")
    y := addFunc("y", "() => do f: () => curFunc(); f(); end")

    verifyEval("x()", normRecFunc(x))
    verifyEval("x()->qname", "proj::x")

    verifyEval("y()", normRecFunc(y))
    verifyEval("y()->qname", "proj::y")
  }

  @HxTestProj
  Void testCompDef()
  {
    src :=
    Str<|defcomp
           a: {dis:"Alpha", awesome:1}
           b: {hidden}
           c: {output, awesome:2}
           do
             c = a + b
           end
         end|>
    x := addFunc("x", src, ["doc":"x hi!"])

    g := (Grid)eval("""compDef("x")""")
    verifyDictEq(g.meta, normRecFunc(x))
    verifyEq(g.size, 3)
    verifyDictEq(g[0], ["name":"a", "dis":"Alpha", "awesome":n(1)])
    verifyDictEq(g[1], ["name":"b", "hidden":m])
    verifyDictEq(g[2], ["name":"c", "output":m, "awesome":n(2)])

    verifyGridEq(g, eval("""compDef(x)"""))
  }

  @HxTestProj
  Void testParams()
  {
    addFunc("foo", "(a, b: true) => a + b")
    addFunc("bar", "(a: 1, b: 1 + 2) => a + b")

    Grid grid := eval("params(commit)")
    verifyEq(grid.size, 1)
    verifyParam(grid, 0, "diffs", null)

    grid = eval("params(foo)")
    verifyEq(grid.size, 2)
    verifyParam(grid, 0, "a", null)
    verifyParam(grid, 1, "b", true)

    grid = eval("params(bar)")
    verifyEq(grid.size, 2)
    verifyParam(grid, 0, "a", n(1))
    verifyParam(grid, 1, "b", n(3))
  }

  Dict normRecFunc(Spec f)
  {
    acc := Etc.dictToMap(f.meta)
    acc.add("qname", f.qname)
    acc.remove("axon")
    return Etc.makeDict(acc)
  }

  Symbol projLib()
  {
    sys.info.rt.isSkySpark ? Symbol("lib:proj_test") : Symbol("lib:hx_db")
  }

  Void verifyParam(Grid grid, Int i, Str name, Obj? def)
  {
    verifyEq(grid[i]->name, name)
    verifyEq(grid[i]["def"], def)
  }

  @HxTestProj
  Void testFuncOverride()
  {
    verifyEval("100.toHex", "64")

    // cannot override core functions
    addFunc("toHex", Str<|(i) => "hex override"|>)
    verifyErr(AmbiguousSpecErr#) { eval("100.toHex") }
  }

  Obj? verifyEval(Str src, Obj? expected)
  {
    actual := eval(src)
    //echo; echo("-- $src"); if (actual is Grid) ((Grid)actual).dump; else echo(actual)
    verifyValEq(actual, expected)
    return actual
  }
}

