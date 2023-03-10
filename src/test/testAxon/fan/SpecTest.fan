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
** SpecTest
**
class SpecTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  Void testSpecs()
  {
    verifySpec(Str<|Str|>, "sys::Str")
    verifySpec(Str<|Dict|>, "sys::Dict")

    libs = ["ph"]
    verifySpec(Str<|Point|>, "ph::Point")
  }

//////////////////////////////////////////////////////////////////////////
// Tyepof function
//////////////////////////////////////////////////////////////////////////

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

    cx := TestContext(this)
    libs.each |x| { cx.usings.add(x) }
    verifyEq(cx.eval(expr), expect)
  }

  |Str,Bool|? verifyIsFunc := null

//////////////////////////////////////////////////////////////////////////
// Fits function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFits()
  {
    rt.libs.add("data")

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
    cx := makeContext
    libs.each |x| { cx.usings.add(x) }
    // echo("   $expr")
    verifyEq(cx.eval(expr), expect)
  }

//////////////////////////////////////////////////////////////////////////
// Fits function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFitsExplain()
  {
    rt.libs.add("data")

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

    cx := makeContext
    libs.each |x| { cx.usings.add(x) }
    grid := (Grid)cx.eval(expr)

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

  Void verifySpec(Str expr, Str qname)
  {
    cx := TestContext(this)
    libs.each |x| { cx.usings.add(x) }
    x := cx.eval(expr)
    // echo("::: $expr => $x [$x.typeof]")
    verifySame(x, data.type(qname))
  }

  DataEnv data() { DataEnv.cur }
}