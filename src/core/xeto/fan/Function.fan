//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2024  Brian Frank  Creation
//

using concurrent

**
** Function is a computation modeled by the 'sys::Func' spec.
**
@Js
mixin Function
{
  ** Return if this function must be called asynchronously
  abstract Bool isAsync()

  ** Call the function with component and argument.
  ** Raise exception if the function must be called async.
  abstract Obj? call(Comp self, Obj? arg)

  ** Call the function with component and argument asynchronously.
  ** Invoke the given callback with an exception or result object.
  abstract Void callAsync(Comp self, Obj? arg, |Err?,Obj?| cb)
}


**************************************************************************
** MethodFunction
**************************************************************************

**
** Implementation of Function that wraps Fantom method
**
@NoDoc @Js
const class MethodFunction : Function
{
  new make(Method method) { this.method = method }

  override Bool isAsync() { false }

  override Obj? call(Comp self, Obj? arg)
  {
    method.callOn(self, [arg])
  }

  override Void callAsync(Comp self, Obj? arg, |Err?,Obj?| cb)
  {
    try
      cb(null, call(self, arg))
    catch (Err e)
      cb(e, null)
  }

  private const Method method
}

**************************************************************************
** SyncFunction
**************************************************************************

**
** Function that wraps synchronous Fantom function
**
@NoDoc @Js
class SyncFunction : Function
{
  new make(|Comp self, Obj? arg->Obj?| func) { this.func = func }

  override Bool isAsync() { false }

  override Obj? call(Comp comp, Obj? arg)
  {
    func.call(comp, arg)
  }

  override Void callAsync(Comp self, Obj? arg, |Err?,Obj?| cb)
  {
    try
      cb(null, call(self, arg))
    catch (Err e)
      cb(e, null)
  }

  private |Comp self, Obj? arg->Obj?| func
}

**************************************************************************
** AsyncFunction
**************************************************************************

**
** Function that wraps asynchronous Fantom function
**
@NoDoc @Js
class AsyncFunction : Function
{
  new make(|Comp self,Obj? arg, |Err?,Obj?| cb| func) { this.func = func }

  override Bool isAsync() { true }

  override Obj? call(Comp comp, Obj? arg)
  {
    throw Err("Must use callAsync")
  }

  override Void callAsync(Comp self, Obj? arg, |Err?,Obj?| cb)
  {
    func.call(self, arg, cb)
  }

  private |Comp self,Obj? arg, |Err?,Obj?| cb| func
}

