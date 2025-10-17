//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    10 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack

**
** Manage Xeto specs and instances in the project companion library
**
const mixin ProjCompanion
{
  ** Get the project companion lib. If the companion lib cannot be
  ** compiled then return null or raise exception based on checked flag.
  abstract Lib? lib(Bool checked := true)

  ** Get a unique digest for the current project companion lib version.
  ** Return null if the project lib is current in an error state.
  @NoDoc abstract Str? libDigest()

  ** Get simple error message to use if project companion lib is in error
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

  ** Add an axon function.  This parses the axon param signature
  ** and generates the correct xeto spec.  Raise exception if axon
  ** cannot be parsed.  Return new func spec.
  abstract Spec addFunc(Str name, Str src, Dict meta := Etc.dict0)

  ** Update an axon function source code and/or meta.  If src or meta
  ** is null, then we leave the old value. This parses the axon param
  ** signature and generates the correct xeto spec.  Raise exception if
  ** axon cannot be parsed.  Return new func spec.
  abstract Spec updateFunc(Str name, Str? src, Dict? meta := null)
}

