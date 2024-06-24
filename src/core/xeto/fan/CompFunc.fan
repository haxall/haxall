//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2023  Brian Frank  Creation
//

using concurrent

**
** CompFunc is a computation stored as a component slot to define a method
**
@Js
mixin CompFunc
{
  ** Call the function with component and argument
  abstract Obj? call(Comp self, Obj? arg)
}


**************************************************************************
** FantomMethodCompFunc
**************************************************************************

**
** Implementation of CompFunc that wraps Fantom method
**
@NoDoc @Js
const class FantomMethodCompFunc : CompFunc
{
  new make(Method method) { this.method = method }
  override Obj? call(Comp comp, Obj? arg) { method.callOn(comp, [arg]) }
  private const Method method
}

**************************************************************************
** FantomFuncCompFunc
**************************************************************************

**
** Implementation of CompFunc that wraps Fantom function
**
@NoDoc @Js
class FantomFuncCompFunc : CompFunc
{
  new make(Func cb) { this.cb = cb }
  override Obj? call(Comp comp, Obj? arg) { cb.call(comp, arg) }
  private const Func cb
}

