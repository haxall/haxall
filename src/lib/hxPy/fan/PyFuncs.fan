//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jul 2021  Matthew Giannini  Creation
//

using haystack
using axon
using hx

**
** Axon functions for py
**
const class PyFuncs
{

  static private PyLib lib() { HxContext.curHx.rt.lib("py") }

  @Axon static PySession py(Dict? opts := null) { lib.mgr.open(opts) }

  // // @Axon static PyIPc pyTimeout(PyIpc py, Number val) { py.timeout(val.toDuration) }

  @Axon static PySession pyDefine(PySession py, Str name, Obj? val) { py.define(name, val) }

  @Axon static PySession pyExec(PySession py, Str code) { py.exec(code) }

  @Axon static Obj? pyEval(PySession py, Str stmt, Number? timeout := null)
  {
    val := py.eval(stmt, timeout?.toDuration)
    try { py.close } catch (Err ignore) { }
    return val
  }

}