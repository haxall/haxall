//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Feb 2023  Brian Frank  Creation
//

**
** SpecSlots is a map of named Specs
**
@Js
const mixin SpecSlots
{
  ** Return if slots are empty
  abstract Bool isEmpty()

  ** Return if the given slot name is defined.
  abstract Bool has(Str name)

  ** Return if the given slot name is undefined.
  abstract Bool missing(Str name)

  ** Get the child slot spec
  abstract Spec? get(Str name, Bool checked := true)

  ** Convenience to list the slots names; prefer `each`.
  abstract Str[] names()

  ** Iterate through the children
  abstract Void each(|Spec val| f)

  ** Iterate through the children until function returns non-null
  abstract Obj? eachWhile(|Spec val->Obj?| f)

  ** Get the slots as Dict of the specs.
  @NoDoc abstract Dict toDict()

}