//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Convert a StatusStr to a StatusNumber. The string may contain a unit, such as "100m".
** If the string cannot be parsed as a number, then out is set to NaN and fault.
**
class StatusStrToStatusNumber : HxComp
{
  /* ionc-start */

  virtual StatusStr? in() { get("in") }

  virtual StatusNumber? out() { get("out") }

  /* ionc-end */

  override Void onExecute()
  {
    str := in
    if (str == null) return set("out", null)

    num := Number.fromStr(str.val, false)
    converted := num == null
      ? StatusNumber(Number.nan, Status.fault)
      : StatusNumber(num, in.status)
    set("out", converted)
  }
}

