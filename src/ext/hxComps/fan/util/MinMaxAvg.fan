//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Computes the min, max, and avg of up to 10 inputs.
**
@Gen
class MinMaxAvg : HxComp
{
  ** Input A
  @Gen virtual StatusNumber? inA() { get("inA") }

  ** Input B
  @Gen virtual StatusNumber? inB() { get("inB") }

  ** Input C
  @Gen virtual StatusNumber? inC() { get("inC") }

  ** Input D
  @Gen virtual StatusNumber? inD() { get("inD") }

  ** Input E
  @Gen virtual StatusNumber? inE() { get("inE") }

  ** Input F
  @Gen virtual StatusNumber? inF() { get("inF") }

  ** Input G
  @Gen virtual StatusNumber? inG() { get("inG") }

  ** Input H
  @Gen virtual StatusNumber? inH() { get("inH") }

  ** Input I
  @Gen virtual StatusNumber? inI() { get("inI") }

  ** Input J
  @Gen virtual StatusNumber? inJ() { get("inJ") }

  ** The minimum value
  @Gen virtual StatusNumber? min() { get("min") }

  ** The maximum value
  @Gen virtual StatusNumber? max() { get("max") }

  ** Average of non-null inputs
  @Gen virtual StatusNumber? avg() { get("avg") }

  override Void onExecute()
  {
    count  := 0
    sum    := 0f
    min    := Float.posInf
    max    := Float.negInf
    10.times |x|
    {
      input := get("in"+('A'+x).toChar) as StatusNumber
      if (input == null) return
      num := input.num.toFloat
      if (num.isNaN) return
      min = min.min(num)
      max = max.max(num)
      sum += num
      count++
    }
    set("min", count == 0 ? null : StatusNumber(Number(min)))
    set("max", count == 0 ? null : StatusNumber(Number(max)))
    set("avg", count == 0 ? null : StatusNumber(Number(sum/count)))
  }
}

