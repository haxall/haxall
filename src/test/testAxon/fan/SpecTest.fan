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

  Void test()
  {
    verifySpec(Str<|Str|>, "sys::Str")
    verifySpec(Str<|Dict|>, "sys::Dict")

    verifySpec(Str<|Point|>, "ph::Point", ["ph"])
  }

  Void verifySpec(Str expr, Str qname, Str[] includes := [,])
  {
    cx := TestContext(this)
    includes.each |x| { cx.usings.add(x) }
    x := cx.eval(expr)
    // echo("::: $expr => $x [$x.typeof]")
    verifySame(x, data.type(qname))
  }

  DataEnv data() { DataEnv.cur }
}