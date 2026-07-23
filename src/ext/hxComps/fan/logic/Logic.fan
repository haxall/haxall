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
** The base spec for all logic components
**
@Gen
abstract class Logic : HxComp
{
  ** The computed value
  @Gen virtual StatusBool? out() { get("out") }
}

**
** Computes the logical negation of its input
**
@Gen
class Not : Logic
{
  @Gen virtual StatusBool? in() { get("in") }

  override Void onExecute()
  {
    a := in

    // if input is null, then set out to null
    if (a == null) return set("out", null)

    // compute the value and set the output
    set("out", StatusBool(calculate(a.val), a.status))
  }

  private Bool calculate(Bool a) { !a }
}

