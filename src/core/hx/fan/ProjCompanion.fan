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

  ** Read all companion rt records
  abstract Dict[] readAll()

  ** Read the companion rt record by id.  Raise exception or return
  ** null if id does not exist or does not map to companion rt rec.
  abstract Dict? readById(Ref id, Bool checked := true)

  ** Read the companion rt record by name.  Raise exception or return
  ** null if name does not exist or does not map to companion rt rec.
  abstract Dict? readByName(Str name, Bool checked := true)

  ** Add a new spec or instance rt companion record. The given dict
  ** must match the AST respresentation as described in class header.
  ** Raise exception if a definition already exists for the defined name.
  ** Return new companion rt record.  The namespace is reloaded on next access.
  abstract Dict add(Dict rec)

  ** Replace an existing companion rt record by id. The given dict must match
  ** the AST respresentation as described in class header. Raise exception
  ** if no existing definition for the dict id.  Return updated rt record.
  ** The namespace is reloaded on next access.
  abstract Dict update(Dict rec)

  ** Remove the companion rt rec from database.  Raise exception if id
  ** does not map to a exisiting rt record.  The namespace is reloaded
  ** on next access.
  abstract Void remove(Ref id)

  ** Parse Xeto source representation into its rt rec AST representation.
  abstract Dict parse(Str xeto)

  ** Parse Axon source representation into its rt rec AST representation.
  abstract Dict parseAxon(Str name, Str xeto, Dict? meta := null)

  ** Print to Xeto source representation from its rt rec AST representation.
  abstract Str print(Dict dict)

  ** Print to Axon source representation from its rt rec AST representation.
  abstract Str printAxon(Dict dict)
}

