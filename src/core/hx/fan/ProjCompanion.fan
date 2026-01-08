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
**   - base: ref qname for base type
**   - slots: grid with cols: name, type ref,  plus col for each meta
**   - any other tags are spec meta
**   - all type references must be a qname ref
**
** Instance record AST format:
**   - rt: required to be "instance"
**   - name: unique str name in companion lib
**   - spec: must be anything other than @sys::Spec
**   - any other tags for instance data
**
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
  ** reloaded on next access.  If id/mod tags are passsed then they must
  ** match the existing record in database.
  abstract Void update(Dict rec)

  ** Rename an existing spec or instance in the companion lib.
  ** Raise exception if no existing definition for oldName or newName
  ** already exists.  The namespace is reloaded on next access.
  abstract Void rename(Str oldName, Str newName)

  ** Remove the spec or instance definition by name from companion lib.
  ** Ignore this call if there is no definition for name.  The namespace
  ** is reloaded on next access.
  abstract Void remove(Str name)

  ** Parse Xeto source representation into its rt rec AST representation.
  abstract Dict parse(Str xeto)

  ** Parse Axon source representation into its rt rec AST representation.
  abstract Dict parseAxon(Str name, Str xeto, Dict? meta := null)

  ** Print to Xeto source representation from its rt rec AST representation.
  abstract Str print(Dict dict)

  ** Print to Axon source representation from its rt rec AST representation.
  abstract Str printAxon(Dict dict)
}

