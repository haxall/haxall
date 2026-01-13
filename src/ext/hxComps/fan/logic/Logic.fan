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
abstract class Logic : HxComp
{
  /* ionc-start */

  ** The computed value
  virtual StatusBool? out() { get("out") }

  /* ionc-end */
}

**
** Computes the logical negation of its input
**
class Not : Logic
{
  /* ionc-start */

  virtual StatusBool? in() { get("in") }

  /* ionc-end */

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

