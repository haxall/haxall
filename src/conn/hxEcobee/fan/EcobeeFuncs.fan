//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Feb 2022  Matthew Giannini  Creation
//

using concurrent
using haystack
using hx
using axon

**
** Ecobee connector funcs
**
const class EcobeeFuncs
{
  private static EcobeeExt ext(Context cx := Context.cur) { cx.proj.ext("hx.ecobee") }
}

