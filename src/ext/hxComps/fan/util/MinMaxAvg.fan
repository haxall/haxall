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
class MinMaxAvg : HxComp
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

  ** Input E
  virtual StatusNumber? inE() { get("inE") }

  ** Input F
  virtual StatusNumber? inF() { get("inF") }

  ** Input G
  virtual StatusNumber? inG() { get("inG") }

  ** Input H
  virtual StatusNumber? inH() { get("inH") }

  ** Input I
  virtual StatusNumber? inI() { get("inI") }

  ** Input J
  virtual StatusNumber? intJ { get {get("intJ")} set {set("intJ", it)} }

  ** The minimum value
  virtual StatusNumber? min() { get("min") }

  ** The maximum value
  virtual StatusNumber? max() { get("max") }

  ** Average of non-null inputs
  virtual StatusNumber? avg() { get("avg") }

  /* ionc-end */

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

