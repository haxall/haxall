//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Sep 2024  Matthew Giannini  Creation
//

using xeto
using haystack

**
** The base spec for all math components that operate on up to four inputs.
** Inputs with an invalid status are not used in the calculation, but their
** status is still propagated to out.
**
@Gen
abstract class QuadMath : Math
{
  ** Input A
  @Gen virtual StatusNumber? inA() { get("inA") }

  ** Input B
  @Gen virtual StatusNumber? inB() { get("inB") }

  ** Input C
  @Gen virtual StatusNumber? inC() { get("inC") }

  ** Input D
  @Gen virtual StatusNumber? inD() { get("inD") }

  final override Void onExecute()
  {
    a := inA
    b := inB
    c := inC
    d := inD

    // only valid inputs are used in the calculation
    va := valid(a)
    vb := valid(b)
    vc := valid(c)
    vd := valid(d)

    numValid := 0
    if (va != null) ++numValid
    if (vb != null) ++numValid
    if (vc != null) ++numValid
    if (vd != null) ++numValid

    // force null if we don't have enough valid inputs
    if (numValid < minInputs) return set("out", null)

    // compute propagated flags from all inputs, including invalid ones
    status := Status.ok
      .merge(a?.status)
      .merge(b?.status)
      .merge(c?.status)
      .merge(d?.status)

    // compute value; incompatible units put out in fault
    val := Number.nan
    try
      val = calculate(va, vb, vc, vd)
    catch (UnitErr e)
      status = status.set(Status.fault)

    // set output
    set("out", StatusNumber(val, status))
  }

  private static StatusNumber? valid(StatusNumber? x) { x != null && x.status.isValid ? x : null }

  protected abstract Int minInputs()

  ** Calculate the value from the valid inputs. Invalid inputs are null.
  protected abstract Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
}

**
** Computes the sum of its inputs
**
@Gen
class Add : QuadMath
{
  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    acc := Number.zero
    if (a != null) acc += a.num
    if (b != null) acc += b.num
    if (c != null) acc += c.num
    if (d != null) acc += d.num
    return acc
  }
}

**
** Computes the product of its inputs
**
@Gen
class Multiply : QuadMath
{
  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    acc := Number.one
    if (a != null) acc *= a.num
    if (b != null) acc *= b.num
    if (c != null) acc *= c.num
    if (d != null) acc *= d.num
    return acc
  }
}

**
** Computes the average of its inputs
**
@Gen
class Average : QuadMath
{
  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    count := 0
    sum := Number.zero
    if (a != null) { sum += a.num; ++count }
    if (b != null) { sum += b.num; ++count }
    if (c != null) { sum += c.num; ++count }
    if (d != null) { sum += d.num; ++count }
    return sum / Number(count)
  }
}

**
** Finds the maximum value of its valid inputs and sets that value to out.
** out = max(inA, inB, inC, inD)
**
@Gen
class Maximum : QuadMath
{
  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    Number? max := a?.num
    if (b != null) max = max == null ? b.num : max.max(b.num)
    if (c != null) max = max == null ? c.num : max.max(c.num)
    if (d != null) max = max == null ? d.num : max.max(d.num)
    return max
  }
}

**
** Finds the minimum value of its valid inputs and sets that value to out.
** out = min(inA, inB, inC, inD)
**
@Gen
class Minimum : QuadMath
{
  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    Number? min := a?.num
    if (b != null) min = min == null ? b.num : min.min(b.num)
    if (c != null) min = min == null ? c.num : min.min(c.num)
    if (d != null) min = min == null ? d.num : min.min(d.num)
    return min
  }
}

