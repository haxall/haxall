//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Feb 2016  Brian Frank  Creation
//

using haystack
using axon
using testHaystack

**
** AxonFilterTest
**
@Js
class AxonFilterTest : FilterTest
{

  override Filter verifyParse(Str s, Filter expected, Str pattern, Str[] tags, Str axon := s)
  {
    cx := TestContext(this)
    expr := cx.parse(axon)
    f := expr.evalToFilter(cx)
    verifyEq(f, expected)

    return super.verifyParse(s, expected, pattern, tags, axon)
  }

  Void testInvalid()
  {
    verifyInvalid(Str<|"site"|>)
    verifyInvalid(Str<|"alpha beta"|>)
    verifyInvalid(Str<|"alpha/beta"|>)
  }

  Void verifyInvalid(Str axon)
  {
    cx := TestContext(this)
    expr := cx.parse(axon)
    verifyEq(expr.evalToFilter(cx, false), null)
    try
    {
      expr.evalToFilter(cx)
      fail
    }
    catch (Err e)
    {
      verifyEq(e.toStr.contains("Expr is not a filter"), true)
    }
  }

}