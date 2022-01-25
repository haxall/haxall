//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jun 2016  Brian Frank      Creation
//  20 Jan 2022  Matthew Giannini Redesign for Haxall
//

using concurrent
using haystack
using hx

**
** SerialPort models the definition and current status of a serial port.
**
const class SerialPort
{
  ** Cosntructor
  internal new make(Dict meta)
  {
    this.meta   = meta
    this.name   = meta->name
    this.device = meta->device
  }

  ** Meta data
  const Dict meta

  ** Logical name
  const Str name

  ** Platform specific device name
  const Str device

  ** Is this serial port currently open and bound to a connector
  Bool isOpen() { owner != null }

  ** Is this serial port current closed and unused
  Bool isClosed() { owner == null }

   ** HxRuntime of the  `owner` if port is open or null if closed
  HxRuntime? rt() { rtRef.val }

  ** Current record which opened and owns the port or null if closed.
  Dict? owner() { ownerRef.val }

  ** Debug string
  override Str toStr() { "SerialPort $name.toCode [$device]" }

  internal const AtomicRef rtRef := AtomicRef(null)
  internal const AtomicRef ownerRef := AtomicRef(null)
}