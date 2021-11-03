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

  @Axon{ admin=true }
  static PySession py(Dict? opts := null) { lib.mgr.open(opts) }

  @Axon{ admin=true }
  static PySession pyTimeout(PySession py, Number? val) { py.timeout(val?.toDuration) }

  @Axon{ admin=true }
  static PySession pyDefine(PySession py, Str name, Obj? val) { py.define(name, val) }

  @Axon{ admin=true }
  static PySession pyExec(PySession py, Str code) { py.exec(code) }

  @Axon{ admin=true }
  static Obj? pyEval(PySession py, Str stmt, Bool close := true)
  {
    val := py.eval(stmt)
    if (close) try { py.close } catch (Err ignore) { lib.log.debug("Failed to close", ignore) }
    return val
  }

}