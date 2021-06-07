//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//

using haystack
using axon
using folio

**
** Haxall core "hx" library supported by all runtimes
**
abstract const class HxCoreLib : HxLib
{
  ** Core axon functions supported by all runtimes
  override abstract HxCoreFuncs funcs()
}