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
** The base spec for all logic components that operate on up to four inputs
**
@Gen
abstract class QuadLogic : Logic
{
  ** Input A
  @Gen virtual StatusBool? inA() { get("inA") }

  ** Input B
  @Gen virtual StatusBool? inB() { get("inB") }

  ** Input C
  @Gen virtual StatusBool? inC() { get("inC") }

  ** Input D
  @Gen virtual StatusBool? inD() { get("inD") }

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

    // calculate value
    v := calculate(a?.val, b?.val, c?.val, d?.val)

    // compute propagated status flags
    s := Status.ok
      .merge(a?.status)
      .merge(b?.status)
      .merge(c?.status)
      .merge(d?.status)

    // set output
    set("out", StatusBool(v, s))
  }

  protected abstract Int minInputs()
  protected abstract Bool calculate(Bool? a, Bool? b, Bool? c, Bool? d)
}

**
** Computes the logical "and" of its inputs
**
@Gen
class And : QuadLogic
{

  override protected const Int minInputs := 1

  protected override Bool calculate(Bool? a, Bool? b, Bool? c, Bool? d)
  {
    val := true
    if (a != null) val = val && a
    if (b != null) val = val && b
    if (c != null) val = val && c
    if (d != null) val = val && d
    return val
  }
}

**
** Computes the logical "or" of its inputs
**
@Gen
class Or : QuadLogic
{

  override protected const Int minInputs := 1

  protected override Bool calculate(Bool? a, Bool? b, Bool? c, Bool? d)
  {
    val := false
    if (a != null) val = val || a
    if (b != null) val = val || b
    if (c != null) val = val || c
    if (d != null) val = val || d
    return val
  }
}

**
** Computes the exclusive-or of its inputs
**
@Gen
class Xor : QuadLogic
{

  override protected const Int minInputs := 2

  protected override Bool calculate(Bool? a, Bool? b, Bool? c, Bool? d)
  {
    val := false
    if (a != null) val = val.xor(a)
    if (b != null) val = val.xor(b)
    if (c != null) val = val.xor(c)
    if (d != null) val = val.xor(d)
    return val
  }
}

