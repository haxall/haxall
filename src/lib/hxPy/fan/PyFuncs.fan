//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jul 2021  Matthew Giannini  Creation
//

using concurrent
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
  **   - 'image': name of the Docker image to run. By default, the lib will
  **   try to run the following images in this order:
  **     1. 'ghcr.io/haxall/hxpy:<ver>' (where ver = current library Haxall version)
  **     1. 'ghcr.io/haxall/hxpy:latest'
  **     1. 'ghcr.io/haxall/hxpy:main'
  **   - 'logLevel': log level of the hxpy python process in Docker. Valid values
  **   are 'WARN', 'INFO', 'DEBUG', (default='WARN')
  **
  ** The default timeout for `pyEval()` is 5min. Use `pyTimeout()` to change this timeout.
  **
  ** Sessions created in the context of a task are persistent, meaning they will
  ** not be closed until the task is killed.
  @Axon{ admin=true }
  static PySession py(Dict? opts := null)
  {
    lib.openSession(opts)
  }

  ** Set the timeout for `pyEval()`.
  @Axon{ admin=true }
  static PySession pyTimeout(PySession py, Number? val) { py.timeout(val?.toDuration) }

  ** Initialize the python session by calling the given func to do any one-time
  ** setup of the python session. If 'pyInit()' has already been called on this
  ** session, then the callback is not invoked.
  **
  ** Typically, this func is used in the context of a task since the python
  ** session in a task is persistent. This allows to do any one-time `pyExec()`
  ** or `pyDefine()` when the task is first creatd.
  @Axon { admin=true }
  static PySession pyInit(PySession py, Fn fn) { py.init(fn.toFunc) }

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
  ** The session will be closed unless it is running in a task.
  @Axon{ admin=true }
  static Obj? pyEval(PySession py, Str stmt)
  {
    try
    {
      return py.eval(stmt)
    }
    finally
    {
      try { py.close } catch (Err ignore) { lib.log.debug("Failed to close python session", ignore) }
    }
  }
}