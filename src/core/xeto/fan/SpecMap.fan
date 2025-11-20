//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Feb 2023  Brian Frank  Creation
//

**
** SpecMap is a map of named Specs
**
** NOTE: in most cases name keys match the 'Spec.name' of slot specs
** themselves. However, in cases where the slot name is an auto-name
** of "_0", "_1", etc its possible that the slot name keys do **not** match
** their slot names.  This occurs when inheriting auto-named slots.  The
** spec names are assigned uniquely per type, but when merged by inheritance
** might be assigned new unique names. This often occurs in queries such as
** point queries.
**
@Js
const mixin SpecMap
{
  ** Return if slots are empty
  abstract Bool isEmpty()

  ** Return if the given slot name is defined.
  ** NOTE: the name key may not match slot name
  abstract Bool has(Str name)

  ** Return if the given slot name is undefined.
  ** NOTE: the name key may not match slot name
  abstract Bool missing(Str name)

  ** Get the child slot spec as keyed by this slots map
  ** NOTE: the name key may not match slot name
  abstract Spec? get(Str name, Bool checked := true)

  ** Convenience to list the slots names; prefer `each`.
  ** NOTE: the names may not match slots names
  abstract Str[] names()

  ** Iterate through the children using key.
  ** NOTE: the name parameter may not match slots names
  abstract Void each(|Spec, Str| f)

  ** Iterate through the children until function returns non-null
  ** NOTE: the name parameter may not match slots names
  abstract Obj? eachWhile(|Spec, Str->Obj?| f)

  ** Get the slots as Dict of the specs.
  @NoDoc abstract Dict toDict()

}

