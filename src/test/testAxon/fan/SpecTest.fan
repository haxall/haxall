//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023  Brian Frank  Creation
//

using haystack
using axon

**
** SpecTest
**
@Js
class SpecTest : AxonTest
{

  Void test()
  {
    verifyEval(Str<|Str|>, "Str")
  }

}