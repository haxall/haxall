//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Sep 2024  Matthew Giannini  Creation
//

using xeto
using haystack

**
** The base spec for all math components
**
@Gen
abstract class Math : HxComp
{
  ** The computed value. If the result is NaN, such as an input outside the
  ** domain of the operation or incompatible units, then the status is fault.
  @Gen virtual StatusNumber? out() { get("out") }
}

