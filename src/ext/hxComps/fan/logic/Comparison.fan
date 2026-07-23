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

  protected override Bool calculate(Number a, Number b) { a == b }
}

**
** Computes A != B
**
@Gen
class NotEqual : Comparison
{

  protected override Bool calculate(Number a, Number b) { a != b }
}

