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
using folio

**
** Proj is the API to work with a project database
**
const mixin Proj
{
  ** Project name
  abstract Str name()

  ** Project id which is always formatted as "p:{name}"
  abstract Ref id()

  ** Project metadata
  abstract Dict meta()

  ** Base directory for project
  abstract File dir()

  ** Folio database
  abstract Folio db()

  ** Xeto namespace
  abstract Namespace ns()

  ** Xeto library managment APIs
  abstract ProjLibs libs()

  ** Extension management APIs
  abstract ProjExts exts()
}

