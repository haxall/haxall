//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using util
using hx

**
** Base class for libs designed to run only in hxd runtime
**
abstract const class HxdLib : HxLib
{
  ** Callback when all libs are fully started.
  ** This is called on dedicated background actor.
  virtual Void onReady() {}

  ** Callback before we stop the runtime
  ** This is called on dedicated background actor.
  virtual Void onUnready() {}
}



