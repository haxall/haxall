//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Dec 2021  Brian Frank  Creation
//

using haystack
using folio
using hx

**
** ConnState manages the mutable state and logic for a connector.
** It routes to ConnDispatch for connector specific behavior.
**
internal class ConnState
{
  ** Constructor with parent connector
  new make(ConnDispatch dispatch)
  {
    this.conn = dispatch.conn
    this.dispatch = dispatch
  }

  const Conn conn
  Ref id() { conn.id }
  Dict rec() { conn.rec }

  ** Handle actor message
  Obj? onReceive(HxMsg msg)
  {
    switch (msg.id)
    {
      case "ping":         return onPing
      case "close":        return onClose
      case "sync":         return null
      case "connUpdated":  dispatch.onConnUpdated; return null
      case "pointAdded":   dispatch.onPointAdded(msg.a); return null
      case "pointUpdated": dispatch.onPointUpdated(msg.a); return null
      case "pointRemoved": dispatch.onPointRemoved(msg.a); return null
      default:             return dispatch.onReceive(msg)
    }
  }

  private Dict onPing()
  {
    return rec
  }

  private Dict onClose()
  {
    return rec
  }

  private ConnDispatch dispatch
}