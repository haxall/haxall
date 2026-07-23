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
** Bit-wise masking operation
**
@Gen
abstract class BitMask : HxComp
{
  ** The input number
  @Gen virtual StatusNumber? in() { get("in") }

  ** The mask to apply to when doing the bit operation
  @Gen virtual StatusNumber? mask { get {get("mask")} set {set("mask", it)} }

  ** The computed value
  @Gen virtual StatusNumber? out() { get("out") }

  override Void onExecute()
  {
    if (in == null || mask == null) return set("out", null)
    result := calculate(in.num.toInt, mask.num.toInt)
    set("out", StatusNumber(Number(result), in.status.merge(mask.status)))
  }

  protected abstract Int calculate(Int a, Int mask)
}

**
** Compute the bitwise `and` value of the input and the mask
**
@Gen
class BitAnd : BitMask
{
  protected override Int calculate(Int a, Int mask) { a.and(mask) }
}

**
** Compute the bitwise `or` value of the input and the mask
**
@Gen
class BitOr : BitMask
{
  protected override Int calculate(Int a, Int mask) { a.or(mask) }
}

**
** Compute the bitwise `xor` (exclusive or) of the input and the mask
**
@Gen
class BitXor : BitMask
{
  protected override Int calculate(Int a, Int mask) { a.xor(mask) }
}

