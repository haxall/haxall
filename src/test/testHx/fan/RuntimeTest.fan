//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using haystack
using axon
using hx

**
** RuntimeTest
**
class RuntimeTest : HxTest
{
  @HxRuntimeTest
  Void testBasics()
  {
     x := addRec(["dis":"It works!"])
     y := rt.db.readById(x.id)
     verifyEq(y.dis, "It works!")
  }

}