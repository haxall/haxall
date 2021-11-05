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

//////////////////////////////////////////////////////////////////////////
// PySession
//////////////////////////////////////////////////////////////////////////

  ** Create a new `hxPy::PySession` instance. Options:
  **   - 'image': name of the Docker image to run. (default='hxpy:latest')
  **   - 'logLevel': log level of the hxpy python process in Docker. Valid values
  **   are 'WARN', 'INFO', 'DEBUG', (default='WARN')
  @Axon{ admin=true }
  static PySession py(Dict? opts := null) { lib.mgr.open(opts) }

  ** Set the timeout for `pyEval()`.
  @Axon{ admin=true }
  static PySession pyTimeout(PySession py, Number? val) { py.timeout(val?.toDuration) }

  ** Define a variable to be available to python code running in the session.
  @Axon{ admin=true }
  static PySession pyDefine(PySession py, Str name, Obj? val) { py.define(name, val) }

  ** Execute the given python code in the session and return the python session.
  ** Note: python 'exec()' does not return a value, so use `pyEval()` if you need
  ** the result of running a python statement. This method is primarily useful
  ** for declaring functions that you want available when using `pyEval()`.
  @Axon{ admin=true }
  static PySession pyExec(PySession py, Str code) { py.exec(code) }

  ** Evalue the given python statement in the session, and return the result.
  @Axon{ admin=true }
  static Obj? pyEval(PySession py, Str stmt)
  {
    try
    {
      return py.eval(stmt)
    }
    finally
    {
      try { py.close } catch (Err ignore) { lib.log.debug("Failed to close", ignore) }
    }
  }
}