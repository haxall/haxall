//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxRuntime
//

using concurrent
using xeto
using haystack
using obs
using folio

**
** Proj manages a project database
**
const mixin Proj : Runtime
{
  ** Project spec management
  abstract ProjSpecs specs()
}

