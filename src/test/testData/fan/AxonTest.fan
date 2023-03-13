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
// Specs Exprs
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSpecExprs()
  {
    // simple
    libs = ["ph"]
    verifySpecExpr(Str<|Str|>, "sys::Str")
    verifySpecExpr(Str<|Dict|>, "sys::Dict")
    verifySpecExpr(Str<|Point|>, "ph::Point")

    // with meta
    verifySpecExpr(Str<|Dict <>|>, "sys::Dict")
    verifySpecExpr(Str<|Dict <foo>|>, "sys::Dict", ["foo":m])
    verifySpecExpr(Str<|Dict <foo, bar:"baz">|>, "sys::Dict", ["foo":m, "bar":"baz"])

    // with slots
    verifySpecExpr(Str<|Dict {}|>, "sys::Dict")
    verifySpecExpr(Str<|Dict { equip }|>, "sys::Dict", [:], ["equip":"sys::Marker"])
    verifySpecExpr(Str<|Dict { equip, ahu }|>, "sys::Dict", [:], ["equip":"sys::Marker", "ahu":"sys::Marker"])
    verifySpecExpr(Str<|Dict { equip, ahu, }|>, "sys::Dict", [:], ["equip":"sys::Marker", "ahu":"sys::Marker"])
    verifySpecExpr(Str<|Dict
                        {
                           equip
                           ahu
                        }|>, "sys::Dict", [:], ["equip":"sys::Marker", "ahu":"sys::Marker"])
    verifySpecExpr(Str<|Dict { dis:Str }|>, "sys::Dict", [:], ["dis":"sys::Str"])
    verifySpecExpr(Str<|Dict { dis:Str, foo, baz:Date }|>, "sys::Dict", [:], ["dis":"sys::Str", "foo":"sys::Marker", "baz":"sys::Date"])
    verifySpecExpr(Str<|Dict {
                         dis:Str
                         foo,
                         baz:Date }|>, "sys::Dict", [:], ["dis":"sys::Str", "foo":"sys::Marker", "baz":"sys::Date"])
    verifySpecExpr(Str<|Dict { Ahu }|>, "sys::Dict", [:], ["_0":"ph::Ahu"])
    verifySpecExpr(Str<|Dict { Ahu, Meter }|>, "sys::Dict", [:], ["_0":"ph::Ahu", "_1":"ph::Meter"])

    // with slot and meta
    verifySpecExpr(Str<|Dict <foo> { bar }|>, "sys::Dict", ["foo":m], ["bar":"sys::Marker"])
    verifySpecExpr(Str<|Dict {
                         dis: Str <qux>
                         foo,
                         baz: Date <x:"y">}|>, "sys::Dict", [:], ["dis":"sys::Str <qux>", "foo":"sys::Marker", "baz":"sys::Date <x:y>"])
  }

  Void verifySpecExpr(Str expr, Str qname, Str:Obj meta := [:], Str:Str slots := [:])
  {
    type := data.type(qname)

echo
echo("::: $expr => ")
    DataSpec x := makeContext.eval(expr)
echo("::: => $x [$x.typeof]")

    // type reference only
    if (meta.isEmpty && slots.isEmpty)
    {
      verifySame(x, type)
      return
    }

    // verify spec
    verifySame(x.type, type)
    verifySame(x.base, type)
    verifyDictEq(x.own, meta)
    slots.each |expect, name|
    {
      verifySpecExprSlot(x.slotOwn(name), expect)
    }
  }

  Void verifySpecExprSlot(DataSpec x, Str expect)
  {
    s := StrBuf().add(x.type.qname)
    if (expect.contains("<"))
    {
      s.add(" <")
      x.own.each |v, n|
      {
        s.add(n)
        if (v !== Marker.val) s.add(":").add(v)
      }
      s.add(">")
    }
    verifyEq(s.toStr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Reflection Funcs
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testReflect()
  {
    verifyReflect("Obj", data.type("sys::Obj"))
    verifyReflect("Str", data.type("sys::Str"))
    verifyReflect("Dict", data.type("sys::Dict"))
    verifyReflect("LibOrg", data.type("sys::LibOrg"))
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
  }

//////////////////////////////////////////////////////////////////////////
// Is function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testIs()
  {
    verifyIs(Str<|is("hi", Str)|>, true)
    verifyIs(Str<|is("hi", Marker)|>, false)
    verifyIs(Str<|is("hi", Dict)|>, false)

    verifyIs(Str<|is(marker(), Str)|>, false)
    verifyIs(Str<|is(marker(), Marker)|>, true)
    verifyIs(Str<|is(marker(), Dict)|>, false)

    verifyIs(Str<|is({}, Str)|>, false)
    verifyIs(Str<|is({}, Marker)|>, false)
    verifyIs(Str<|is({}, Dict)|>, true)

    verifyIs(Str<|is(Str, Obj)|>, true)
    verifyIs(Str<|is(Str, Scalar)|>, true)
    verifyIs(Str<|is(Str, Str)|>, true)
    verifyIs(Str<|is(Str, Marker)|>, false)
    verifyIs(Str<|is(Str, Dict)|>, false)

    libs = ["ph"]
    verifyIs(Str<|is(Meter, Obj)|>, true)
    verifyIs(Str<|is(Meter, Dict)|>, true)
    verifyIs(Str<|is(Meter, Entity)|>, true)
    verifyIs(Str<|is(Meter, Equip)|>, true)
    verifyIs(Str<|is(Meter, Point)|>, false)
    verifyIs(Str<|is(Meter, Str)|>, false)
  }

  Void verifyIs(Str expr, Bool expect)
  {
    // override hook to reuse is() tests for fits()
    if (verifyIsFunc != null) return verifyIsFunc(expr, expect)

    verifyEval(expr, expect)
  }

  |Str,Bool|? verifyIsFunc := null

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
    // TODO
    //testIs

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
    verifySame(x, data.type(qname))
  }

  DataEnv data() { DataEnv.cur }
}