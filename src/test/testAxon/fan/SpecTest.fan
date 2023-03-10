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
    verifyEval(Str<|is("hi", Str)|>, true)
    verifyEval(Str<|is("hi", Marker)|>, false)
    verifyEval(Str<|is("hi", Dict)|>, false)

    verifyEval(Str<|is(marker(), Str)|>, false)
    verifyEval(Str<|is(marker(), Marker)|>, true)
    verifyEval(Str<|is(marker(), Dict)|>, false)

    verifyEval(Str<|is({}, Str)|>, false)
    verifyEval(Str<|is({}, Marker)|>, false)
    verifyEval(Str<|is({}, Dict)|>, true)

    verifyEval(Str<|is(Str, Obj)|>, true)
    verifyEval(Str<|is(Str, Scalar)|>, true)
    verifyEval(Str<|is(Str, Str)|>, true)
    verifyEval(Str<|is(Str, Marker)|>, false)
    verifyEval(Str<|is(Str, Dict)|>, false)

    libs = ["ph"]
    verifyEval(Str<|is(Meter, Obj)|>, true)
    verifyEval(Str<|is(Meter, Dict)|>, true)
    verifyEval(Str<|is(Meter, Entity)|>, true)
    verifyEval(Str<|is(Meter, Equip)|>, true)
    verifyEval(Str<|is(Meter, Point)|>, false)
    verifyEval(Str<|is(Meter, Str)|>, false)
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