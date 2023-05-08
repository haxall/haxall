//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Aug 2013  Andy Frank       Creation
//   12 Apr 2016  Brian Frank      Port to 3.0
//   20 Jan 2022  Matthew Giannini Redesign for Haxall
//

using haystack

**
** SerialConfig defines the configuration to open a `SerialPort`.  This class
** encodes all the config into a string format which may be added to
** connectors to define how they bind to a serial port.
**
const class SerialConfig
{
  ** It-block ctor.
  new make(|This| f)
  {
    f(this)
    if (!Etc.isTagName(name))     throw ArgErr("Invalid name '$name'")
    if (data   < 5 || data   > 8) throw ArgErr("Invalid data '$data'")
    if (parity < 0 || parity > 2) throw ArgErr("Invalid parity '$parity'")
    if (stop   < 1 || stop   > 2) throw ArgErr("Invalid stop 'stop'")
    if (flow   < 0 || flow   > 2) throw ArgErr("Invalid flow '$flow'")
  }

  ** Logical port name
  const Str name

  ** Port baud rate (ex: 9600, 38400, 115200)
  const Int baud := 115200

  ** Number of data bits to use (5..8).
  const Int data := 8

  ** Partiy mode: `parityNone`, `parityOdd`, `parityEven`.
  const Int parity := parityNone

  static const Int parityNone := 0
  static const Int parityOdd  := 1
  static const Int parityEven := 2

  ** Number of stop bits to use (1..2).
  const Int stop := 1

  ** Flow control mode: `flowNone`, `flowRtsCts`, `flowXonXoff`
  const Int flow := flowRtsCts

  static const Int flowNone    := 0
  static const Int flowRtsCts  := 1
  static const Int flowXonXoff := 2

  ** Hash is toStr.hash
  override Int hash() { toStr.hash }

  ** Configs are equal if every setting is equal.
  override Bool equals(Obj? obj)
  {
    if (obj isnot SerialConfig) return false
    that := (SerialConfig)obj
    return name   == that.name   &&
           baud   == that.baud   &&
           data   == that.data   &&
           parity == that.parity &&
           stop   == that.stop   &&
           flow   == that.flow
  }

  ** Str representation:
  **    {name}-{baud}-{data}{parity}{stop}-{flow}
  **    foo-115200-8n1-rtscts
  override Str toStr()
  {
    // baud
    buf := StrBuf().add(name).addChar('-').add(baud.toStr)

    // data/parity/stop
    buf.addChar('-')
    buf.add(data.toStr)
    switch (parity)
    {
      case parityOdd:   buf.addChar('o')
      case parityEven:  buf.addChar('e')
      default:          buf.addChar('n')
    }
    buf.add(stop)

    // flow control
    buf.addChar('-')
    switch (flow)
    {
      case flowNone:   buf.add("none")
      case flowRtsCts: buf.add("rtscts")
      default:         buf.add("xonxoff")
    }

    return buf.toStr
  }

  ** Parse from Str.
  static new fromStr(Str str, Bool checked := true)
  {
    try
    {
      parts  := str.split('-')
      name   := parts[0]
      baud   := parts[1].toInt
      dps    := parts[2]
      fstr   := parts.getSafe(3) ?: ""
      data   := dps[0..<1].toInt
      parity := dps[1]=='o' ? parityOdd : (dps[1]=='e' ? parityEven : parityNone)
      stop   := dps[2..<3].toInt
      flow   := fstr=="none" ? flowNone : (fstr=="xonxoff" ? flowXonXoff : flowRtsCts)
      return SerialConfig
      {
        it.name   = name
        it.baud   = baud
        it.data   = data
        it.parity = parity
        it.stop   = stop
        it.flow   = flow
      }
    }
    catch (Err err)
    {
      if (!checked) return null
      throw ParseErr("Invalid format: $str", err)
    }
  }
}