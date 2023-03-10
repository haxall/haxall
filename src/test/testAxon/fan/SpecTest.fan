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

**
** SpecTest
**
@Js
class SpecTest : AxonTest
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
    verifyEval(expr, expect)
    verifyEval(expr.replace("is(", "fits("), expect)
  }

//////////////////////////////////////////////////////////////////////////
// Fits function
//////////////////////////////////////////////////////////////////////////

  Void testFits()
  {
    verifyFits(Str<|fits("hi", Str)|>, true)
    verifyFits(Str<|fits("hi", Marker)|>, false)
    verifyFits(Str<|fits("hi", Dict)|>, false)

    libs = ["ph"]
    verifyFits(Str<|fits({site}, Str)|>, false)
    verifyFits(Str<|fits({site}, Dict)|>, true)
//    verifyFits(Str<|fits({site}, Site)|>, true)
    verifyFits(Str<|fits({site}, Equip)|>, false)
  }

  Void verifyFits(Str expr, Bool expect)
  {
//    echo("   $expr")
    verifyEval(expr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verifySpec(Str expr, Str qname)
  {
    x := eval(expr)
    // echo("::: $expr => $x [$x.typeof]")
    verifySame(x, data.type(qname))
  }

  DataEnv data() { DataEnv.cur }
}