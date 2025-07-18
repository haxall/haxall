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

  ** Get simple error message to use if project lib is in error
  @NoDoc abstract Str? libErrMsg()

  ** List the spec names defined
  abstract Str[] list()

  ** Read source code for given project spec
  abstract Str? read(Str name, Bool checked := true)

  ** Add new spec to project and reload namespace
  abstract Spec add(Str name, Str body)

  ** Update source for given project spec and reload namespace
  abstract Spec update(Str name, Str body)

  ** Rename project spec and reload namespace
  abstract Spec rename(Str oldName, Str newName)

  ** Remove given project spec and reload namespace
  abstract Void remove(Str name)
}

