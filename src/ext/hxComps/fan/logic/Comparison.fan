//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Sep 2024  Matthew Giannini  Creation
//

using xeto
using haystack

**
** The base spec for all mathematical comparison operators
**
abstract class Comparison : Logic
{
  /* ionc-start */

  ** Input A
  virtual StatusNumber? inA() { get("inA") }

  ** Input B
  virtual StatusNumber? inB() { get("inB") }

  /* ionc-end */

  final override Void onExecute()
  {
    a := inA
    b := inB

    // if either input is null, set out to null
    if (a == null || b == null) return set("out", null)

    // compute value and status flags
    v := a.status.isValid && b.status.isValid
      ? calculate(a.val, b.val)
      : false
    s := a.status.merge(b.status)

    // set the output
    set("out", StatusBool(v, s))
  }

  protected abstract Bool calculate(Number a, Number b)
}

**
** Computes A > B
**
class GreaterThan : Comparison
{
  /* ionc-start */

  /* ionc-end */

  protected override Bool calculate(Number a, Number b) { a > b }
}

**
** Computes A >= B
**
class GreaterThanEqual : Comparison
{
  /* ionc-start */

  /* ionc-end */

  protected override Bool calculate(Number a, Number b) { a >= b }
}

**
** Computes A < B
**
class LessThan : Comparison
{
  /* ionc-start */

  /* ionc-end */

  protected override Bool calculate(Number a, Number b) { a < b }
}

**
** Computes A <= B
**
class LessThanEqual : Comparison
{
  /* ionc-start */

  /* ionc-end */

  protected override Bool calculate(Number a, Number b) { a <= b }
}

**
** Computes A == B
**
class Equal : Comparison
{
  /* ionc-start */

  /* ionc-end */

  protected override Bool calculate(Number a, Number b) { a == b }
}

**
** Computes A != B
**
class NotEqual : Comparison
{
  /* ionc-start */

  /* ionc-end */

  protected override Bool calculate(Number a, Number b) { a != b }
}

