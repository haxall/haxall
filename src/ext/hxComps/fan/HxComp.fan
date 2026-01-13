//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Aug 2024  Matthew Giannini  Creation
//

using xeto
using haystack

**
** A "bindable" component. It can report what it's current "output" value is,
** and optionally supports setting its "input" value.
**
mixin BindableComp : Comp
{
  ** Set the input slot for this component, or throw an Err if not supported
  virtual Void bindIn(Obj? val)
  {
    throw UnsupportedErr("${typeof} cannot be bound for input")
  }

  ** Get the output value for this component
  abstract StatusVal? bindOut()
}

** Base class for all components in this library
abstract class HxComp : CompObj, BindableComp
{
  CompContext cx() { CompContext.curComp }

  override StatusVal? bindOut() { get("out") as StatusVal }
}