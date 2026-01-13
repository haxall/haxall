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
** The base spec for all math components that operate on two inputs
**
abstract class BinaryMath : Math
{
  /* ionc-start */

  ** Input A
  virtual StatusNumber? inA() { get("inA") }

  ** Input B
  virtual StatusNumber? inB() { get("inB") }

  /* ionc-end */

  override Void onExecute()
  {
    a := inA
    b := inB

    // if either input is null, set out to null
    if (a == null || b == null) return set("out", null)

    // compute value and status
    v := a.status.isValid && b.status.isValid
      ? calculate(a.val, b.val)
      : Number.nan
    s := a.status.merge(b.status)

    // set the output
    set("out", StatusNumber(v, s))
  }

  protected abstract Number calculate(Number a, Number b)
}

**
** Computes the difference of its inputs (A - B)
**
class Subtract : BinaryMath
{
  /* ionc-start */

  /* ionc-end */

  protected override Number calculate(Number a, Number b) { a - b }
}

**
** Computes the quotient of its inputs (A / B)
**
class Divide : BinaryMath
{
  /* ionc-start */

  /* ionc-end */

  protected override Number calculate(Number a, Number b) { a / b }
}

**
** Computes the modulus of its inputs (A % B)
**
class Modulus : BinaryMath
{
  /* ionc-start */

  /* ionc-end */

  protected override Number calculate(Number a, Number b) { a % b }
}

**
** Computes a raised to the b power: out = inA ^ inB
**
class Power : BinaryMath
{
  /* ionc-start */

  /* ionc-end */

  protected override Number calculate(Number a, Number b) { Number(a.toFloat.pow(b.toFloat)) }
}

