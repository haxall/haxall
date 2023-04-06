//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//    6 Apr 2023  Brian Frank  Creation
//

using util

**
** Inherit slots from base type
**
@Js
internal class Inherit : Step
{
  override Void run()
  {
    ast.walk |x|
    {
      obj := x as AObj
      if (obj != null)
      {
        inherit(obj)
      }
    }
    bombIfErr
  }

  private Void inherit(AObj x)
  {
  }

}