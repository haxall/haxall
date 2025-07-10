//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    10 Jul 2025  Brian Frank  Creation
//

using xeto

**
** Manage Xeto specs in the project library
**
const mixin ProjSpecs
{
  ** Get the project lib
  abstract Lib lib()

  ** Add new spec to project and reload namespace
  abstract Spec add(Str name, Str body)

  ** Update source for given project spec and reload namespace
  abstract Spec update(Str name, Str body)

  ** Remove given project spec and reload namespace
  abstract Void remove(Str name)
}

