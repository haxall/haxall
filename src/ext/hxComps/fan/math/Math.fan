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
abstract class Math : HxComp
{
  /* ionc-start */

  ** The computed value
  virtual StatusNumber? out() { get("out") }

  /* ionc-end */
}

