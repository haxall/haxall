//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** A bit-wise masking operation
**
abstract class BitMask : HxComp
{
  /* ionc-start */

  ** The input number
  virtual StatusNumber? in() { get("in") }

  ** The mask to apply to when doing the bit operation
  virtual StatusNumber? mask { get {get("mask")} set {set("mask", it)} }

  ** The computed value
  virtual StatusNumber? out() { get("out") }

  /* ionc-end */

  override Void onExecute()
  {
    if (in == null || mask == null) return set("out", null)
    result := calculate(in.num.toInt, mask.num.toInt)
    set("out", StatusNumber(Number(result), in.status.merge(mask.status)))
  }

  protected abstract Int calculate(Int a, Int mask)
}

**
** Compute the bitwise 'and' value of the input and the mask
**
class BitAnd : BitMask
{
  /* ionc-start */

  /* ionc-end */

  protected override Int calculate(Int a, Int mask) { a.and(mask) }
}

**
** Compute the bitwise 'or' value of the input and the mask
**
class BitOr : BitMask
{
  /* ionc-start */

  /* ionc-end */

  protected override Int calculate(Int a, Int mask) { a.or(mask) }
}

**
** Compute the bitwise 'xor' (exclusive or) of the input and the mask
**
class BitXor : BitMask
{
  /* ionc-start */

  /* ionc-end */

  protected override Int calculate(Int a, Int mask) { a.xor(mask) }
}

