//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Nov 2024  Brian Frank  Creation
//

using util

**
** Choice APIs for a specific choice spec via `LibNamespace.choice`.
**
@Js
const mixin SpecChoice
{
  ** Spec for this choice - might be slot or choice type
  abstract Spec spec()

  ** Choice type for the spec
  abstract Spec type()

  ** Return if the choice slot allows zero selections
  abstract Bool isMaybe()

  ** Return if the choice slot allows multiple selections
  abstract Bool isMultiChoice()

  ** Return all choice selections the given instance implements
  ** without regard to validation.
  abstract Spec[] selections(Dict instance)

  ** Return single choice selection or null with validation.
  abstract Spec? selection(Dict instance, Bool checked := true)
}

