//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Generate the DocSpec instances
**
internal class GenSpecs : Step
{
  override Void run()
  {
    eachSpec |spec| { gen(spec) }
  }

  Void gen(Spec spec)
  {
  }
}

