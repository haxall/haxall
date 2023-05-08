//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    2 Feb 2016  Brian Frank       Creation
//   25 Jan 2022  Matthew Giannini  Redesign for Haxall
//

using concurrent
using haystack

**
** TestSerialSpi
**
@NoDoc
const class TestSerialSpi : PlatformSerialSpi
{
  override const SerialPort[] ports := [
    SerialPort(Etc.makeDict(["name":"test", "device":"/test"]))
  ]

  override SerialSocket open(SerialPort port, SerialConfig config)
  {
    TestSerialSocket(port, config)
  }

  override Void close(SerialSocket socket)
  {
  }
}

**************************************************************************
** TestSerialPort
**************************************************************************

@NoDoc class TestSerialSocket : SerialSocket
{
  new make(SerialPort port, SerialConfig config) : super(port, config) {}

  override InStream in() { buf.in }

  override OutStream out() { buf.out }

  override This purge() { buf.clear; return this }

  Buf buf := Buf()
}

