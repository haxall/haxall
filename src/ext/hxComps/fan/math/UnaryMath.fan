//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Sep 2024  Matthew Giannini  Creation
//

using xeto
using haystack

**
** The base spec for all math components that operate on one input
**
@Gen
abstract class UnaryMath : Math
{
  ** Input A
  @Gen virtual StatusNumber? inA() { get("inA") }

  override Void onExecute()
  {
    a := inA

    // if the input is null, force the output to null
    if (a == null) return set("out", null)

    set("out", StatusNumber(calculate(a.val), a.status))
  }

  protected abstract Number calculate(Number a)
}

**
** Computes the absolute value of its input
**
@Gen
class AbsValue : UnaryMath
{
  protected override Number calculate(Number a) { a.abs }
}

**
** Computes out = e ^ inA where `e` is Euler's number
**
@Gen
class Exponential : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.exp) }
}

**
** Computes out = inA!
**
@Gen
class Factorial : UnaryMath
{
  override Void onExecute()
  {
    super.onExecute()

    // put the output in fault if factorial goes to infinity
    if (out.val == Number.posInf)
    {
      set("out", StatusNumber(out.val, out.status.set(Status.fault)))
    }
  }

  protected override Number calculate(Number a)
  {
    acc := 1f
    f   := a.toInt
    for (i := 1; i <= f; ++i)
    {
      acc *= i
      if (acc == Float.posInf || acc == Float.negInf) return Number.posInf
    }
    return Number(acc)
  }
}

**
** Computes the log base 10 of its input: out = log10(inA)
**
@Gen
class LogBase10 : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.log10) }
}

**
** Computes the natural logarithm of its input: out = ln(inA)
**
@Gen
class LogNatural : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.log) }
}

**
** Computes the negation of its input: out = -inA
**
@Gen
class Negative : UnaryMath
{
  protected override Number calculate(Number a) { -a }
}

**
** Computes the square root of its input: out = sqrt(inA)
**
@Gen
class SquareRoot : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.sqrt) }
}

**
** Computes the sine of its input: out = sin(inA)
**
@Gen
class Sine : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.sin) }
}

**
** Computes the cosine of its input: out = cos(inA)
**
@Gen
class Cosine : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.cos) }
}

**
** Computes the cosine of its input: out = tan(inA)
**
@Gen
class Tangent : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.tan) }
}

**
** Computes the arcsine of its input: out = asin(inA)
**
@Gen
class ArcSine : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.asin) }
}

**
** Computes the arccosine of its input: out = acos(inA)
**
@Gen
class ArcCosine : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.acos) }
}

**
** Computes the arctangent of its input: out = atan(inA)
**
@Gen
class ArcTangent : UnaryMath
{
  protected override Number calculate(Number a) { Number(a.toFloat.atan) }
}

