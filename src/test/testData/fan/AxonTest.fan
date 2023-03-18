//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023  Brian Frank  Creation
//

using data
using haystack
using axon
using hx

**
** AxonTest
**
class AxonTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Setup
//////////////////////////////////////////////////////////////////////////

  override Void setup()
  {
    super.setup
    rt := rt(false)
    if (rt != null) rt.libs.add("data")
  }

//////////////////////////////////////////////////////////////////////////
// SpecsExpr
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSpecExpr()
  {
    // simple
    libs = ["ph"]
    verifySpecRef(Str<|Str|>, "sys::Str")
    verifySpecRef(Str<|Dict|>, "sys::Dict")
    verifySpecRef(Str<|Point|>, "ph::Point")

    // slot
    libs = ["ph"]
    verifySpecRef(Str<|Equip.equip|>, "ph::Equip.equip")
    verifySpecRef(Str<|Equip.points|>, "ph::Equip.points")

    // with meta
    verifySpecDerive(Str<|Dict <>|>, "sys::Dict")
    verifySpecDerive(Str<|Dict <foo>|>, "sys::Dict", ["foo":m])
    verifySpecDerive(Str<|Dict <foo,>|>, "sys::Dict", ["foo":m])
    verifySpecDerive(Str<|Dict <foo, bar:"baz">|>, "sys::Dict", ["foo":m, "bar":"baz"])
    verifySpecDerive(Str<|Dict <a:"1">|>, "sys::Dict", ["a":"1"])
    verifySpecDerive(Str<|Dict <a:"1", b:"2">|>, "sys::Dict", ["a":"1", "b":"2"])
    verifySpecDerive(Str<|Dict <a:"1", b:"2", c:"3">|>, "sys::Dict", ["a":"1", "b":"2", "c":"3"])
    verifySpecDerive(Str<|Dict <a:"1", b:"2", c:"3", d:"4">|>, "sys::Dict", ["a":"1", "b":"2", "c":"3", "d":"4"])
    verifySpecDerive(Str<|Dict <a:"1", b:"2", c:"3", d:"4", e:"5">|>, "sys::Dict", ["a":"1", "b":"2", "c":"3", "d":"4", "e":"5"])
    x := verifySpecDerive(Str<|Dict <of:Str>|>, "sys::Dict", ["of":env.type("sys::Str")])
    verifySame(x->of, env.type("sys::Str"))

    // with value
    verifySpecDerive(Str<|Scalar "foo"|>, "sys::Scalar", ["val":"foo"])
    verifySpecDerive(Str<|Scalar 123|>, "sys::Scalar", ["val":"123"])
    verifySpecDerive(Str<|Scalar 2023-03-13|>, "sys::Scalar", ["val":"2023-03-13"])
    verifySpecDerive(Str<|Scalar 13:14:15|>, "sys::Scalar", ["val":"13:14:15"])
    verifySpecDerive(Str<|Scalar <qux> "bar"|>, "sys::Scalar", ["qux":m, "val":"bar"])

    // with slots
    verifySpecDerive(Str<|Dict {}|>, "sys::Dict")
    verifySpecDerive(Str<|Dict { equip }|>, "sys::Dict", [:], ["equip":"sys::Marker"])
    verifySpecDerive(Str<|Dict { equip, ahu }|>, "sys::Dict", [:], ["equip":"sys::Marker", "ahu":"sys::Marker"])
    verifySpecDerive(Str<|Dict { equip, ahu, }|>, "sys::Dict", [:], ["equip":"sys::Marker", "ahu":"sys::Marker"])
    verifySpecDerive(Str<|Dict
                          {
                             equip
                             ahu
                          }|>, "sys::Dict", [:], ["equip":"sys::Marker", "ahu":"sys::Marker"])
    verifySpecDerive(Str<|Dict { dis:Str }|>, "sys::Dict", [:], ["dis":"sys::Str"])
    verifySpecDerive(Str<|Dict { dis:Str, foo, baz:Date }|>, "sys::Dict", [:], ["dis":"sys::Str", "foo":"sys::Marker", "baz":"sys::Date"])
    verifySpecDerive(Str<|Dict {
                            dis:Str
                            foo,
                            baz:Date
                          }|>, "sys::Dict", [:], ["dis":"sys::Str", "foo":"sys::Marker", "baz":"sys::Date"])
    verifySpecDerive(Str<|Dict { Ahu }|>, "sys::Dict", [:], ["_0":"ph::Ahu"])
    verifySpecDerive(Str<|Dict { Ahu, Meter }|>, "sys::Dict", [:], ["_0":"ph::Ahu", "_1":"ph::Meter"])

    // with slot and meta
    verifySpecDerive(Str<|Dict <foo> { bar }|>, "sys::Dict", ["foo":m], ["bar":"sys::Marker"])
    verifySpecDerive(Str<|Dict {
                            dis: Str <qux>
                            foo,
                            baz: Date <x:"y">
                          }|>, "sys::Dict", [:], ["dis":"sys::Str <qux>", "foo":"sys::Marker", "baz":"sys::Date <x:y>"])

    // maybe
    verifySpecDerive(Str<|Dict?|>, "sys::Dict", ["maybe":m])
    verifySpecDerive(Str<|Dict? <foo>|>, "sys::Dict", ["maybe":m, "foo":m])

    // and/or
    ofs := DataSpec[env.type("ph::Meter"), env.type("ph::Chiller")]
    verifySpecDerive(Str<|Meter & Chiller|>, "sys::And", ["ofs":ofs])
    verifySpecDerive(Str<|Meter | Chiller|>, "sys::Or",  ["ofs":ofs])
    verifySpecDerive(Str<|Meter & Chiller <foo>|>, "sys::And", ["ofs":ofs, "foo":m])
    verifySpecDerive(Str<|Meter | Chiller <foo>|>, "sys::Or",  ["ofs":ofs, "foo":m])
// TODO
//    verifySpecDerive(Str<|Meter & Chiller { foo: Str }|>, "sys::And", ["ofs":DataSpec[env.type("ph::Meter"), env.type("ph::Chiller")]], ["foo":"sys::Str"])
  }

  DataSpec verifySpecRef(Str expr, Str qname)
  {
    DataSpec x := makeContext.eval(expr)
    // echo(":::REF:::: $expr => $x [$x.typeof]")
    verifySame(x, env.spec(qname))
    return x
  }

  DataSpec verifySpecDerive(Str expr, Str type, Str:Obj meta := [:], Str:Str slots := [:])
  {
    DataSpec x := makeContext.eval(expr)
    // echo(":::DERIVE::: $expr => $x [$x.typeof] " + Etc.dictToStr((Dict)x.own))

    // verify spec
    verifyNotSame(x, env.type(type))
    verifySame(x.type, env.type(type))
    verifySame(x.base, x.type)
    verifyDictEq(x.own, meta)
    slots.each |expect, name|
    {
      verifySpecExprSlot(x.slotOwn(name), expect)
    }
    return x
  }

  Void verifySpecExprSlot(DataSpec x, Str expect)
  {
    s := StrBuf().add(x.type.qname)
    if (expect.contains("<"))
    {
      s.add(" <")
      x.each |v, n|
      {
        if (x.type.has(n)) return
        s.add(n)
        if (v !== Marker.val) s.add(":").add(v)
      }
      s.add(">")
    }
    verifyEq(s.toStr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Deftype
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testDeftype()
  {
    cx := makeContext
    person := cx.eval(Str<|Person: Dict|>)
    verifySame(cx.varsInScope.getChecked("Person"), person)
    verifySame(cx.eval("Person"), person)
    verifyEq(cx.eval("specParent(Person)"), null)
    verifyEq(cx.eval("specName(Person)"), "Person")
    verifyEq(cx.eval("specBase(Person)"), env.type("sys::Dict"))
    verifyEq(cx.eval("specType(Person)"), env.type("sys::Dict"))
    verifySame(cx.eval("specMetaOwn(Person)"), env.dict0)
    verifyEq(cx.eval("specSlotsOwn(Person).isEmpty"), true)

    person2 := cx.eval(Str<|Person2: Person { dis:Str }|>)
    verifySame(cx.varsInScope.getChecked("Person2"), person2)
    verifySame(cx.eval("Person2"), person2)
    verifyEq(cx.eval("specParent(Person2)"), null)
    verifyEq(cx.eval("specName(Person2)"), "Person2")
    verifyEq(cx.eval("specBase(Person2)"), person)
    verifyEq(cx.eval("specType(Person2)"), env.type("sys::Dict"))
    verifySame(cx.eval("specMetaOwn(Person2)"), env.dict0)
    verifyEq(cx.eval("specSlotsOwn(Person2)->dis.specName"), "dis")
    verifyEq(cx.eval("specSlotsOwn(Person2)->dis.specType"), env.type("sys::Str"))
  }


//////////////////////////////////////////////////////////////////////////
// Reflection Funcs
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testReflect()
  {
    verifyReflect("Obj", env.type("sys::Obj"))
    verifyReflect("Str", env.type("sys::Str"))
    verifyReflect("Dict", env.type("sys::Dict"))
    verifyReflect("LibOrg", env.type("sys::LibOrg"))
  }

  Void verifyReflect(Str expr, DataSpec spec)
  {
    if (spec is DataType) verifyEval("specLib($expr)", ((DataType)spec).lib)
    verifyEval("specParent($expr)", spec.parent)
    verifyEval("specName($expr)", spec.name)
    verifyEval("specQName($expr)", spec.qname)
    verifyEval("specType($expr)", spec.type)
    verifyEval("specBase($expr)", spec.base)
    verifyDictEq(eval("specMetaOwn($expr)"), spec.own)
    verifyDictEq(eval("specSlots($expr)"), spec.slots.toDict)
    verifyDictEq(eval("specSlotsOwn($expr)"), spec.slotsOwn.toDict)
  }

//////////////////////////////////////////////////////////////////////////
// Tyepof function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testTypeof()
  {
    verifySpec(Str<|typeof(marker())|>, "sys::Marker")
    verifySpec(Str<|typeof("hi")|>, "sys::Str")
    verifySpec(Str<|typeof(@id)|>, "sys::Ref")
    verifySpec(Str<|typeof([])|>, "sys::List")
    verifySpec(Str<|typeof({})|>, "sys::Dict")
    verifySpec(Str<|typeof(Str)|>, "sys::Type")
    verifySpec(Str<|typeof(toGrid("hi"))|>, "ph::Grid")
    verifySpec(Str<|typeof(toGrid("hi"))|>, "ph::Grid")
    verifySpec(Str<|typeof(Str)|>, "sys::Type")
    verifySpec(Str<|typeof(Str <foo>)|>, "sys::Spec")
  }

//////////////////////////////////////////////////////////////////////////
// SpecIs function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSpecIs()
  {
    verifySpecIs(Str<|specIs(Str, Obj)|>,    true)
    verifySpecIs(Str<|specIs(Str, Scalar)|>, true)
    verifySpecIs(Str<|specIs(Str, Str)|>,    true)
    verifySpecIs(Str<|specIs(Str, Marker)|>, false)
    verifySpecIs(Str<|specIs(Str, Dict)|>,   false)

    libs = ["ph"]
    verifySpecIs(Str<|specIs(Meter, Obj)|>,    true)
    verifySpecIs(Str<|specIs(Meter, Dict)|>,   true)
    verifySpecIs(Str<|specIs(Meter, Entity)|>, true)
    verifySpecIs(Str<|specIs(Meter, Equip)|>,  true)
    verifySpecIs(Str<|specIs(Meter, Point)|>,  false)
    verifySpecIs(Str<|specIs(Meter, Str)|>,    false)
  }

  Void verifySpecIs(Str expr, Bool expect)
  {
    // override hook to reuse specIs() tests for specFits()
    if (verifySpecIsFunc != null) return verifySpecIsFunc(expr, expect)

    verifyEval(expr, expect)
  }

  |Str,Bool|? verifySpecIsFunc := null

//////////////////////////////////////////////////////////////////////////
// Is function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testIs()
  {
    verifyIs(Str<|is("hi", Str)|>,    true)
    verifyIs(Str<|is("hi", Marker)|>, false)
    verifyIs(Str<|is("hi", Dict)|>,   false)

    verifyIs(Str<|is(marker(), Str)|>,    false)
    verifyIs(Str<|is(marker(), Marker)|>, true)
    verifyIs(Str<|is(marker(), Dict)|>,   false)

    verifyIs(Str<|is({}, Str)|>,    false)
    verifyIs(Str<|is({}, Marker)|>, false)
    verifyIs(Str<|is({}, Dict)|>,   true)

  }

  Void verifyIs(Str expr, Bool expect)
  {
    // override hook to reuse is() tests for fits()
    if (verifyIsFunc != null) return verifyIsFunc(expr, expect)

    verifyEval(expr, expect)
  }

  |Str,Bool|? verifyIsFunc := null

//////////////////////////////////////////////////////////////////////////
// SpecFits function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSpecFits()
  {
    // run all the is tests with fits
    verifySpecIsFunc = |Str expr, Bool expect|
    {
      verifySpecFits(expr.replace("specIs(", "specFits("), expect)
    }
    testSpecIs
  }

  Void verifySpecFits(Str expr, Bool expect)
  {
    // echo("   $expr")
    verifyEval(expr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Fits function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFits()
  {
    // run all the is tests with fits
    verifyIsFunc = |Str expr, Bool expect|
    {
      verifyFits(expr.replace("is(", "fits("), expect)
    }
    testIs

    verifyFits(Str<|fits("hi", Str)|>, true)
    verifyFits(Str<|fits("hi", Marker)|>, false)
    verifyFits(Str<|fits("hi", Dict)|>, false)

    libs = ["ph"]
    verifyFits(Str<|fits({site}, Str)|>, false)
    verifyFits(Str<|fits({site}, Dict)|>, true)
    verifyFits(Str<|fits({site}, Equip)|>, false)
    verifyFits(Str<|fits({site}, Site)|>, true)
  }

  Void verifyFits(Str expr, Bool expect)
  {
    // echo("   $expr")
    verifyEval(expr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Fits function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFitsExplain()
  {
    verifyFitsExplain(Str<|fitsExplain({}, Dict)|>, [,])

    libs = ["ph"]
    verifyFitsExplain(Str<|fitsExplain({site}, Site)|>, [,])
    verifyFitsExplain(Str<|fitsExplain({}, Site)|>, [
      "Missing required marker 'site'"
      ])

    verifyFitsExplain(Str<|fitsExplain({ahu, equip}, Ahu)|>, [,])
    verifyFitsExplain(Str<|fitsExplain({}, Ahu)|>, [
      "Missing required marker 'equip'",
      "Missing required marker 'ahu'"
      ])
  }

  Void verifyFitsExplain(Str expr, Str[] expect)
  {

    grid := (Grid)makeContext.eval(expr)

    // echo; echo("-- $expr"); grid.dump

    if (expect.isEmpty) return verifyEq(grid.size, 0)

    verifyEq(grid.size, expect.size+1)
    verifyEq(grid[0]->msg, expect.size == 1 ? "1 error" : "$expect.size errors")
    expect.each |msg, i|
    {
      verifyEq(grid[i+1]->msg, msg)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Query
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testQuery()
  {
    libs = ["ph"]

    ahu       := addRec(["id":Ref("ahu"), "dis":"AHU", "ahu":m, "equip":m])
      mode    := addRec(["id":Ref("mode"), "dis":"Mode", "hvacMode":m, "point":m, "equipRef":ahu.id])
      dduct   := addRec(["id":Ref("dduct"), "dis":"Discharge Duct", "duct":m, "equip":m, "equipRef":ahu.id])
        dtemp := addRec(["id":Ref("dtemp"), "dis":"Discharge Temp", "temp":m, "point":m, "equipRef":dduct.id])
        dflow := addRec(["id":Ref("dflow"), "dis":"Discharge Flow", "flow":m, "point":m, "equipRef":dduct.id])
        dfan  := addRec(["id":Ref("dfan"), "dis":"Discharge Fan", "fan":m, "equip":m, "equipRef":dduct.id])
         drun := addRec(["id":Ref("drun"), "dis":"Discharge Fan Run", "fan":m, "run":m, "point":m, "equipRef":dfan.id])

    // Point.equips
    verifyQuery(mode,  "Point.equips", [ahu])
    verifyQuery(dtemp, "Point.equips", [ahu, dduct])
    verifyQuery(drun,  "Point.equips", [ahu, dduct, dfan])

    // Equip.points
    verifyQuery(dfan,  "Equip.points", [drun])
    verifyQuery(dduct, "Equip.points", [dtemp, dflow, drun])
    verifyQuery(ahu, "  Equip.points", [mode, dtemp, dflow, drun])

    // query with no matches
    verifyEq(eval("query($drun.id.toCode, Equip.points, false)"), null)
    verifyEvalErr("query($drun.id.toCode, Equip.points)", UnknownRecErr#)
    verifyEvalErr("query($drun.id.toCode, Equip.points, true)", UnknownRecErr#)
  }

  Void verifyQuery(Dict rec, Str query, Dict[] expect)
  {
    // no options
    expr := "queryAll($rec.id.toCode, $query)"
    // echo("-- $expr")
    Grid actual := eval(expr)
    origActual := actual
    x := actual.sortDis.mapToList { it.dis }.join(",")
    y := Etc.sortDictsByDis(expect).join(",") { it.dis }
    // echo("   $x ?= $y")
    verifyEq(x, y)

    // sort option
    expr = "queryAll($rec.id.toCode, $query, {sort})"
    actual = eval(expr)
    x = actual.mapToList { it.dis }.join(",")
    y = Etc.sortDictsByDis(expect).join(",") { it.dis }
    verifyEq(x, y)

    // limit  option
    expr = "queryAll($rec.id.toCode, $query, {limit:2})"
    actual = eval(expr)
    if (expect.size == 1)
    {
      verifyEq(actual.size, 1)
      verifyEq(y.contains(actual[0].dis), true)
    }
    else
    {
      verifyEq(actual.size, 2)
      verifyEq(y.contains(actual[0].dis), true)
      verifyEq(y.contains(actual[1].dis), true)
    }

    // query
    single := eval("query($rec.id.toCode, $query)")
    verifyDictEq(single, origActual.first)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Str[] libs := [,]

  override HxContext makeContext(HxUser? user := null)
  {
    cx := super.makeContext(user)
    libs.each |x| { cx.usings.add(x) }
    return cx
  }

  Void verifyEval(Str expr, Obj? expect)
  {
    verifyEq(makeContext.eval(expr), expect)
  }

  Void verifySpec(Str expr, Str qname)
  {
    x := makeContext.eval(expr)
    // echo("::: $expr => $x [$x.typeof]")
    verifySame(x, env.type(qname))
  }

  Void verifyEvalErr(Str expr, Type? errType)
  {
    EvalErr? err := null
    try { eval(expr) } catch (EvalErr e) { err = e }
    if (err == null) fail("EvalErr not thrown: $expr")
    if (errType == null)
    {
      verifyNull(err.cause)
    }
    else
    {
      if (err.cause == null) fail("EvalErr.cause is null: $expr")
      verifyErr(errType) { throw err.cause }
    }
  }

  DataEnv env() { DataEnv.cur }
}