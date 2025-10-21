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
** Spec record AST format:
**   - rt: required to be "spec"
**   - name: unique str name in companion lib
**   - spec: must be @sys::Spec
**   - base: ref for base type
**   - slots: dict of slot AST representation
**   - any other tags are spec meta
**   - each slot is dict {type, slots, meta tag...}
**
** Instance record AST format:
**   - rt: required to be "instance"
**   - name: unique str name in companion lib
**   - spec: must be anything other than @sys::Spec
**   - any other tags for instance data
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

  ** List all records for companion lib specs and instances
  abstract Dict[] list()

  ** Read the record for the given companion lib spec or instance
  abstract Dict? read(Str name, Bool checked := true)

  ** Add a new spec or instance to the companion lib. The given dict
  ** must match the AST respresentation as described in class header.
  ** Raise exception if a definition already exists for the defined name.
  ** The namespace is reloaded on next access.
  abstract Void add(Dict rec)

  ** Update an existing spec or instance to the companion lib. The given
  ** dict must match the AST respresentation as described in class header.
  ** Raise exception if no existing definition for name.  The namespace is
  ** reloaded on next access.
  abstract Void update(Dict rec)

  ** Rename an existing spec or instance in the companion lib.
  ** Raise exception if no existing definition for oldName or newName
  ** already exists.  The namespace is reloaded on next access.
  abstract Void rename(Str oldName, Str newName)

  ** Remove the spec or instance definition by name from companion lib.
  ** Raise exception if no existing definition for name.  The namespace
  ** is reloaded on next access.
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

// OLD API

  ** List the spec names defined
  abstract Str[] _list()

  ** Read source code for given project spec
  abstract Str? _read(Str name, Bool checked := true)

  ** Add new spec to project and reload namespace
  abstract Spec _add(Str name, Str body)

  ** Update source for given project spec and reload namespace
  abstract Spec _update(Str name, Str body)

  ** Rename project spec and reload namespace
  abstract Spec _rename(Str oldName, Str newName)

  ** Remove given project spec and reload namespace
  abstract Void _remove(Str name)
}

