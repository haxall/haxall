//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Helpers for the tests of the CDL math components
**
abstract class MathCompTest : HxCompTest
{
  ** Negative zero, built from its bits since the literal -0f is positive
  static const Float negZero := Float.makeBits(0x8000_0000_0000_0000)

  ** Run f with a test context current
  Void run(|->| f)
  {
    TestHxCompContext().asCur |cx| { f() }
  }

  ** A comp with the given slots, added under the root and executed
  Comp mk(Str spec, Str:Obj? slots := [:])
  {
    c := createComp(spec)
    slots.each |v, n| { c.set(n, v) }
    cs.root.add(c, null)
    cs.execute
    return c
  }

  ** Set slots on c, then execute
  Void put(Comp c, Str:Obj? slots)
  {
    slots.each |v, n| { c.set(n, v) }
    cs.execute
  }

  ** A StatusNumber with a unit symbol or none
  StatusNumber num(Float v, Str? unit := null, Status s := Status.ok)
  {
    StatusNumber(Number(v, unit == null ? null : Unit(unit)), s)
  }

  ** A Number with a unit symbol or none
  Number nu(Float v, Str? unit := null)
  {
    Number(v, unit == null ? null : Unit(unit))
  }

  Void verifyOutNull(Comp c, Str msg := "")
  {
    verifyNull(c.get("out"), msg)
  }

  ** Verify out within tol relative to max(1, |v|), or equal to an
  ** infinite v, its unit and its status
  Void verifyOut(Comp c, Float v, Str? unit := null, Status s := Status.ok, Float tol := 1e-12f)
  {
    o := c.get("out") as StatusNumber
    verifyNotNull(o, "out is null, expected $v")
    a := o.num.toFloat
    if (v.isNaN)
      verify(a.isNaN, "out $a, expected NaN")
    else if (v == Float.posInf || v == Float.negInf)
      verify(a == v, "out $a, expected $v")
    else
      verify((a - v).abs <= tol * v.abs.max(1f), "out $a, expected $v")
    verifyEq(o.num.unit?.symbol, unit, "unit")
    verifyEq(o.status, s, "status")
  }

  ** The float in out, which must not be null
  Float outF(Comp c)
  {
    ((StatusNumber)c.get("out")).num.toFloat
  }
}
