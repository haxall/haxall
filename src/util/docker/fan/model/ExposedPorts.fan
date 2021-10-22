//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Oct 2021  Matthew Giannini  Creation
//


**************************************************************************
** InetProtocol
**************************************************************************

** The supported protocols for exposing ports in a container
enum class InetProtocol { tcp, udp, sctp }

**************************************************************************
** ExposedPort
**************************************************************************

const class ExposedPort
{
  static new fromStr(Str s, Bool checked := true)
  {
    Err? cause := null
    try
    {
      parts := s.split('/')
      port  := Int.fromStr(parts[0])
      if (parts.size == 1) return ExposedPort(port, InetProtocol.tcp)
      if (parts.size == 2) return ExposedPort(port, InetProtocol.fromStr(parts[1]))
    }
    catch (Err x) { cause = x}
    if (checked) throw ArgErr("Invalid ExposedPort: ${s}", cause)
    return null
  }

  static new tcp(Int port) { ExposedPort(port, InetProtocol.tcp) }
  static new udp(Int port) { ExposedPort(port, InetProtocol.udp) }
  static new sctp(Int port) { ExposedPort(port, InetProtocol.sctp) }

  new make(Int port, InetProtocol protocol)
  {
    this.port = port
    this.protocol = protocol
  }

  const Int port

  const InetProtocol protocol

  override Int hash()
  {
    res := 31 + port
    res = (31 * res) + protocol.hash
    return res
  }

  override Bool equals(Obj? obj)
  {
    if (this === obj) return true
    that := obj as ExposedPort
    if (that == null) return false
    if (this.port != that.port) return false
    if (this.protocol != that.protocol) return false
    return true
  }

  Str toJson() { toStr }

  override Str toStr()
  {
    "${port}/${protocol}"
  }
}

**************************************************************************
** ExposedPorts
**************************************************************************

const class ExposedPorts
{
  static new fromJson(Map json)
  {
    ExposedPorts(json.keys.map |key->ExposedPort| { ExposedPort.fromStr(key) })
  }

  new make(ExposedPort[] ports)
  {
    this.ports = ports
  }

  const ExposedPort[] ports

  Map toJson()
  {
    acc := Str:Map[:]
    ports.each |port| { acc[port.toStr] = emptyMap }
    return acc
  }

  override Str toStr()
  {
    buf := StrBuf()
    ports.each |port, i|
    {
      if (i > 0) buf.add(", ")
      buf.add(port)
    }
    return buf.toStr
  }

  private static const Map emptyMap := Str:Obj?[:]
}

**************************************************************************
** PortBinding
**************************************************************************

const class PortBinding
{
  new make(|This| f) { f(this) }

  new makeHostPort(Str hostIp, Int port)
  {
    this.hostIp   = hostIp
    this.hostPort = port.toStr
  }

  new makePort(Int port)
  {
    this.hostPort = port.toStr
  }

  const Str? hostIp

  const Str hostPort

  Int port() { Int.fromStr(hostPort) }

  override Str toStr()
  {
    return hostIp == null ? hostPort : "${hostIp}:${hostPort}"
  }
}