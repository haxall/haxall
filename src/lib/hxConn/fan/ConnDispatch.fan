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
    throw Err("Unknown msg type $msg")
  }
}