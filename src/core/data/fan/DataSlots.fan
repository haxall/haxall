//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Feb 2023  Brian Frank  Creation
//

**
** DataSlots is a map of named DataSpecs
**
@Js
const mixin DataSlots
{
  ** Return if slots are empty
  abstract Bool isEmpty()

  ** Get the child slot spec
  abstract DataSpec? get(Str name, Bool checked := true)

  ** Convenience to list the slots names; prefer `each`.
  abstract Str[] names()

  ** Iterate through the children
  abstract Void each(|DataSpec val| f)

  ** Iterate through the children until function returns non-null
  abstract Obj? eachWhile(|DataSpec val->Obj?| f)

  ** Get the slots as DataDict of the specs.
  @NoDoc abstract DataDict toDict()

}