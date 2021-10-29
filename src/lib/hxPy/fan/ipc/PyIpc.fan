//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jul 2021  Matthew Giannini  Creation
//

using haystack
using hx

**
** Python over IPC
**
class PyIpc
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  internal new make(PyMgr mgr, Dict? opts := null)
  {
    this.mgr = mgr
    this.opts = PyOpts(opts)
  }

  ** The manager that created this instance
  private const PyMgr mgr

  ** Interpreter options
  private PyOpts opts

  ** Instructions to run on the remote daemon
  private Instr[] instrs := Instr[,]

  ** Python process. This is lazily created because we don't
  ** want to start the overhead of OS process and socket until
  ** the first time we eval instructions.
  private PyProcess? _process

//////////////////////////////////////////////////////////////////////////
// PyIpc
//////////////////////////////////////////////////////////////////////////

  ** Get the unique process identifier for this instance
  Str pid() { opts.key }

  ** Shutdown all python IPC
  This close()
  {
    mgr.dealloc(pid)
    return this
  }

  internal Void killProcess()
  {
    _process?.close
    _process = null
  }

//////////////////////////////////////////////////////////////////////////
// Python
//////////////////////////////////////////////////////////////////////////

  ** Set the `eval()` timeout.
  This timeout(Duration timeout)
  {
    opts.timeoutRef.val = timeout
    return this
  }

  ** Define a variable in local scope.
  This define(Str name, Obj? val)
  {
    // TODO: type checking on val?
    instrs.add(DefineInstr(name, val))
    return this
  }

  ** Execute the given code block
  This exec(Str code)
  {
    // Just buffer the exec instruction until an eval is requested
    instrs.add(ExecInstr(code))
    return this
  }

  ** Evaluate the expression and return the result
  Obj? eval(Str expr, Bool close := false)
  {
    try
    {
      instrs.add(EvalInstr(expr))
      return process.send(instrs)
    }
    finally
    {
      instrs.clear
      if (close) this.close
    }
  }

  private PyProcess process()
  {
    if (_process == null) this._process = PyProcess(opts)
    return this._process
  }
}