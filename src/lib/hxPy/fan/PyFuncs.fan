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
  **
  ** Sessions created in the context of a task are persistent, meaning they will
  ** not be closed until the task is killed.
  @Axon{ admin=true }
  static PySession py(Dict? opts := null)
  {
    // get the persistent session if running in a task, otherwise create
    // a non-persistent session.
    task(opts)?.session ?: openSession(opts)
  }

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
      try
      {
        // close the session if not running in a task
        if (task == null) py.close
      }
      catch (Err ignore) { lib.log.debug("Failed to close", ignore) }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Open a new Python session
  static private PySession openSession(Dict? opts) { lib.mgr.open(opts) }

  ** Get the python task adjunct if running in a task; otherwise return null
  static private PyAdjunct? task(Dict? opts := null)
  {
    try
    {
      tasks := (HxTaskService)HxContext.curHx.rt.services.get(HxTaskService#)
      return tasks.adjunct |->HxTaskAdjunct| { PyAdjunct(openSession(opts)) }
    }
    catch (Err err)
    {
      return null
    }
  }
}

**************************************************************************
** PyAdjunct
**************************************************************************

internal const class PyAdjunct : HxTaskAdjunct
{
  new make(PySession session) { this.sessionRef = Unsafe(session) }

  PySession session() { sessionRef.val }
  private const Unsafe sessionRef

  override Void onKill() { session.close }
}


