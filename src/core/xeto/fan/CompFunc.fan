//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Mar 2026  Brian Frank  Creation
//

**
** Component method function.  CompFuncs always take exactly one parameter.
** They can be declared statically as a slot using meta and standard func
** signature pattern, or dynamically in instance data using a dict value.
**
@Js
const mixin CompFunc
{
  ** Slot name of the function in the Comp slot map
  abstract Str name()

  ** Metadata for function
  abstract Dict meta()

  ** Function signature for the parameter and return type
  abstract Spec funcType()

  ** Convenience for `Comp.call` with given component and argument.
  abstract Obj? call(Comp self, Obj? arg)
}

