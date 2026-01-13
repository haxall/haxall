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
** The base spec for all math components that operate on up to four inputs
**
abstract class QuadMath : Math
{
  /* ionc-start */

  ** Input A
  virtual StatusNumber? inA() { get("inA") }

  ** Input B
  virtual StatusNumber? inB() { get("inB") }

  ** Input C
  virtual StatusNumber? inC() { get("inC") }

  ** Input D
  virtual StatusNumber? inD() { get("inD") }

  /* ionc-end */

  final override Void onExecute()
  {
    a := inA
    b := inB
    c := inC
    d := inD

    nonNull := 0
    if (a != null) ++nonNull
    if (b != null) ++nonNull
    if (c != null) ++nonNull
    if (d != null) ++nonNull

    // force null if we don't have enough valid inputs
    forceNull := nonNull < minInputs
    if (forceNull) return set("out", null)

    // compute value
    val := calculate(a, b, c, d)

    // compute propagated flags
    status := Status.ok
      .merge(a?.status)
      .merge(b?.status)
      .merge(c?.status)
      .merge(d?.status)

    // set output
    set("out", StatusNumber(val, status))
  }

  protected abstract Int minInputs()
  protected abstract Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
}

**
** Computes the sum of its inputs
**
class Add : QuadMath
{
  /* ionc-start */

  /* ionc-end */

  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    acc := 0f
    if (a != null) acc += a.num.toFloat
    if (b != null) acc += b.num.toFloat
    if (c != null) acc += c.num.toFloat
    if (d != null) acc += d.num.toFloat
    return Number(acc)
  }
}

**
** Computes the product of its inputs
**
class Multiply : QuadMath
{
  /* ionc-start */

  /* ionc-end */

  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    acc := 1f
    if (a != null) acc *= a.num.toFloat
    if (b != null) acc *= b.num.toFloat
    if (c != null) acc *= c.num.toFloat
    if (d != null) acc *= d.num.toFloat
    return Number(acc)
  }
}

**
** Computes the average of its inputs
**
class Average : QuadMath
{
  /* ionc-start */

  /* ionc-end */

  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    count := 0
    sum := 0f
    if (a != null) { sum += a.num.toFloat; ++count }
    if (b != null) { sum += b.num.toFloat; ++count }
    if (c != null) { sum += c.num.toFloat; ++count }
    if (d != null) { sum += d.num.toFloat; ++count }
    return Number(sum/count)
  }
}

**
** Finds the maximum value of its valid inputs and sets that value to out.
** out = max(inA, inB, inC, inD)
**
class Maximum : QuadMath
{
  /* ionc-start */

  /* ionc-end */

  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    Number? max := a?.num
    if (b != null) max = max == null ? b : max.max(b.num)
    if (c != null) max = max == null ? c : max.max(c.num)
    if (d != null) max = max == null ? d : max.max(d.num)
    return max
  }
}

**
** Finds the minimum value of its valid inputs and sets that value to out.
** out = min(inA, inB, inC, inD)
**
class Minimum : QuadMath
{
  /* ionc-start */

  /* ionc-end */

  override protected const Int minInputs := 1

  override protected Number calculate(StatusNumber? a, StatusNumber? b, StatusNumber? c, StatusNumber? d)
  {
    Number? min := a?.num
    if (b != null) min = min == null ? b : min.min(b.num)
    if (c != null) min = min == null ? c : min.min(c.num)
    if (d != null) min = min == null ? d : min.min(d.num)
    return min
  }
}

