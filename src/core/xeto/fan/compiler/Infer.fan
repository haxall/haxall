//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//    3 Mar 2023  Brian Frank  Redesign from proto
//

using util

**
** Infer unspecified types from inherited specs
**
@Js
internal class Infer : Step
{
  override Void run()
  {
    ast.walk |x|
    {
      if (x is AObj) inferObj(x)
    }
  }

  Void inferObj(AObj x)
  {
    // short circuit if type already specified
    if (x.type != null) return

    // types without a supertype are assumed to be sys::Dict
    if (x.nodeType === ANodeType.type)
    {
      t := (AType)x
      if (t.qname == "sys::Obj") return
      t.type = sys.dict
      return
    }

    // TODO: fallback to Str/Dict
    if (x.val != null)
      x.type = sys.str
    else
      x.type = sys.dict
  }

}