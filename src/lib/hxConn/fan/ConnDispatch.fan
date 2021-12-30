//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Dec 2021  Brian Frank  Creation
//

using hx

**
** ConnDispatch provides an implementation for all callbacks.
** A subclass is created by each connector to implement the various
** callbacks and store mutable state.  All dispatch callbacks
** are executed within the parent Conn actor.
**
abstract class ConnDispatch
{
  ** Constructor with parent connector
  new make(Conn conn) { this.conn = conn }

  ** Parent connector
  const Conn conn

  ** Parent library
  virtual ConnLib lib() { conn.lib }

  ** Handle actor message.
  ** Overrides must call super.
  virtual Obj? onReceive(HxMsg msg)
  {
    switch (msg.id)
    {
      case "sync":         return null
      case "pointAdded":   onPointAdded(msg.a); return null
      case "pointUpdated": onPointUpdated(msg.a); return null
      case "pointRemoved": onPointRemoved(msg.a); return null
      default:             throw Err("Unknown msg type $msg")
    }
  }

  ** Callback when point is added to this connector
  virtual Void onPointAdded(ConnPoint pt) {}

  ** Callback when point record is updated
  virtual Void onPointUpdated(ConnPoint pt) {}

  ** Callback when point is removed from this connector
  virtual Void onPointRemoved(ConnPoint pt) {}
}