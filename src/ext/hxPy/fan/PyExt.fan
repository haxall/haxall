//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jul 2021  Matthew Giannini  Creation
//

using concurrent
using xeto
using hx

**
** Python extension.
**
const class PyExt : ExtObj
{
  ** Construction
  new make()
  {
    this.mgr = PyMgr(this)
  }

  ** Convenience to get the PyExt instance from the current context.
  static PyExt? cur(Bool checked := true)
  {
    Context.cur.ext("hx.py", checked)
  }

  ** Process manager
  internal const PyMgr mgr

  ** Open a new python session or return an existing one if running in the
  ** context of a task
  @NoDoc PySession openSession(Dict? opts := null)
  {
    mgr.openSession(opts)
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle Callbacks
//////////////////////////////////////////////////////////////////////////

  @NoDoc override Void onStop()
  {
    mgr.shutdown
  }

}

