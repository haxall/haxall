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
@Gen
abstract class Comparison : Logic
{
  ** Input A
  @Gen virtual StatusNumber? inA() { get("inA") }

  ** Input B
  @Gen virtual StatusNumber? inB() { get("inB") }

  final override Void onExecute()
  {
    a := inA
    b := inB

    // if either input is null, set out to null
    if (a == null || b == null) return set("out", null)

    // compute value and status flags; incompatible units put out in fault
    s := a.status.merge(b.status)
    v := false
    if (a.status.isValid && b.status.isValid)
    {
      try
        v = calculate(a.val, b.val)
      catch (UnitErr e)
        s = s.set(Status.fault)
    }

    // set the output
    set("out", StatusBool(v, s))
  }

  protected abstract Bool calculate(Number a, Number b)
}

**
** Computes A > B
**
@Gen
class GreaterThan : Comparison
{

  protected override Bool calculate(Number a, Number b) { a > b }
}

**
** Computes A >= B
**
@Gen
class GreaterThanEqual : Comparison
{

  protected override Bool calculate(Number a, Number b) { a >= b }
}

**
** Computes A < B
**
@Gen
class LessThan : Comparison
{

  protected override Bool calculate(Number a, Number b) { a < b }
}

**
** Computes A <= B
**
@Gen
class LessThanEqual : Comparison
{

  protected override Bool calculate(Number a, Number b) { a <= b }
}

**
** Computes A == B
**
@Gen
class Equal : Comparison
{

  protected override Bool calculate(Number a, Number b) { eq(a, b) }

  ** Same semantics as the Axon '==' operator: a unitless number
  ** is equal to a number with the same value and any unit
  internal static Bool eq(Number a, Number b)
  {
    a.toFloat.compare(b.toFloat) == 0 && (a.unit === b.unit || a.unit == null || b.unit == null)
  }
}

**
** Computes A != B
**
@Gen
class NotEqual : Comparison
{

  protected override Bool calculate(Number a, Number b) { !Equal.eq(a, b) }
}

