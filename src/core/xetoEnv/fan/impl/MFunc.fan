//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Feb 2025  Brian Frank  Creation
//

using util
using xeto

**
** Implementation of SpecFunc
**
@Js
const final class MFunc : SpecFunc
{
  static MFunc init(MSpec spec)
  {
    Spec? returns
    params := Spec[,]
    spec.slots.each |slot|
    {
      if (slot.name == "returns")
        returns = slot
      else
        params.add(slot)
    }
    return make(params, returns)
  }

  private new make(Spec[] params, Spec returns)
  {
    this.params = params
    this.returns = returns
  }

  override const Spec[] params

  override const Spec returns

  override Int arity() { params.size }
}

