//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Jan 2022  Matthew Giannini  Creation
//

**
** Serial port service provider interface. An implementation of this mixin
** provides access to the serial ports of the host platform. Concurrent access
** to this SPI is managed by the `SerialLib`.
**
const mixin SerialSpi
{
  ** List available ports and their current status
  abstract SerialPort[] ports()

  ** Open a serial port with the given configuration.
  abstract SerialSocket open(SerialPort port, SerialConfig config)

  ** Close this serial port
  abstract Void close(SerialSocket socket)

}