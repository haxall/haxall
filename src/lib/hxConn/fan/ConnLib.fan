//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using hx

**
** Connector library base class
**
abstract const class ConnLib : HxLib
{
  ** Model which defines tags and functions for this connector.
  ** The model is not available until after the library has started.
  ConnModel model() { modelRef.val ?: throw Err("Not avail until after start") }
  private const AtomicRef modelRef := AtomicRef()

  ** Start callback - if overwritten you *must* call super
  override Void onStart()
  {
    this.modelRef.val = ConnModel(rt.ns, def)
  }

  ** Stop callback - if overwritten you *must* call super
  override Void onStop()
  {
  }
}


