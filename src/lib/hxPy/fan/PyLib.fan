//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jul 2021  Matthew Giannini  Creation
//

using concurrent
using haystack
using hx

**
** Python inter-process communication library
**
const class PyLib : HxLib
{
  ** Construction
  new make()
  {
    this.mgr = PyMgr(this)
  }

  ** Convenience to get the PyLib instance from the current context.
  static PyLib? cur(Bool checked := true)
  {
    HxContext.curHx.rt.lib("py", checked)
  }

  ** Process manager
  internal const PyMgr mgr

  ** Open a new python session
  @NoDoc PySession openSession(Dict? opts := null) { mgr.open(opts) }

//////////////////////////////////////////////////////////////////////////
// Lifecycle Callbacks
//////////////////////////////////////////////////////////////////////////

  override Void onStop()
  {
    mgr.shutdown
  }
}