//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxRuntime
//

using xeto
using folio

**
** HxProj is the API to work with a project database
**
const mixin HxProj
{
  ** Project name
  abstract Str name()

  ** Project id which is always formatted as "p:{name}"
  abstract Ref id()

  ** Project metadata
  abstract Dict meta()

  ** Base directory for project
  abstract File dir()

  ** Xeto namespace
  abstract HxNamespace ns()

  ** Folio database
  abstract Folio db()
}

