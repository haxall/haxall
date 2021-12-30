//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Dec 2021  Brian Frank  Creation
//

using haystack
using folio
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
  new make(Conn conn) { this.connRef = conn }

  ** Runtime system
  HxRuntime rt() { connRef.rt }

  ** Runtime database
  Folio db() { connRef.db }

  ** Parent library
  virtual ConnLib lib() { connRef.lib }

  ** Parent connector
  Conn conn() { connRef }
  private const Conn connRef

  ** Record id
  Ref id() { conn.id }

  ** Debug tracing for this connector
  ConnTrace trace() { conn.trace }

  ** Log for this connector
  Log log() { conn.log }

  ** Display name
  Str dis() { conn.dis }

  ** Current version of the record.
  ** This dict only represents the current persistent tags.
  ** It does not track transient changes such as 'connStatus'.
  Dict rec() { conn.rec }

  ** Callback to handle custom actor messages
  virtual Obj? onReceive(HxMsg msg) { throw Err("Unknown msg: $msg") }

  ** Callback to handle opening the connection.  Raise DownErr or FaultErr
  ** if the connection failed.  This callback is always called before
  ** operations such as `onPing`.
  abstract Void onOpen()

  ** Callback to handle close of the connection.
  abstract Void onClose()

  ** Callback to handle ping of the connector.  Return custom
  ** status tags such as device version, etc to store on the connector
  ** record persistently.  If there are version tags which should be
  ** removed then map those tags to Remove.val.  If ping fails then
  ** raise DownErr or FaultErr.
  abstract Dict onPing()

  ** Callback made periodically every few seconds to handle background tasks.
  virtual Void onHouseKeeping() {}

  ** Callback when conn record is updated
  virtual Void onConnUpdated() {}

  ** Callback when point is added to this connector
  virtual Void onPointAdded(ConnPoint pt) {}

  ** Callback when point record is updated
  virtual Void onPointUpdated(ConnPoint pt) {}

  ** Callback when point is removed from this connector
  virtual Void onPointRemoved(ConnPoint pt) {}
}