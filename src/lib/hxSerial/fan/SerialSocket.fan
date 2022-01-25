//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 May 2013  Andy Frank        Creation
//   12 Apr 2016  Brian Frank       Creation
//   20 Jan 2022  Matthew Giannini  Redesign for Haxall
//

using concurrent

**
** SerialSocket provides I/O access to a serial port opened by `SerialLib.open`
**
abstract class SerialSocket
{
  ** Constructor
  protected new make(SerialLib lib, SerialPort port, SerialConfig config)
  {
    this.lib = lib
    this.port = port
    this.config = config
  }

  ** The serial port definition
  const SerialPort port

  ** Serial system module
  const SerialLib lib

  ** Logical name of port
  Str name() { config.name }

  ** Port configuration
  const SerialConfig config

  ** Timeout for reads, or null for no timeout.
  Duration? timeout := 5sec

  ** Discard any data in read and write buffers.
  abstract This purge()

  ** Get the buffered InStream used to read from this port.
  abstract InStream in()

  ** Get the buffered OutStream used to write to this port.
  abstract OutStream out()

  ** Is this port currently closed
  Bool isClosed() { isClosedRef.val }
  internal const AtomicBool isClosedRef := AtomicBool(false)

  ** Close this serial port
  Void close()
  {
    if (isClosed) return
    lib.close(this)
  }

  ** Debug string
  override Str toStr() { config.toStr }
}

