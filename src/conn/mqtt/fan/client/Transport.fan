//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  05 Apr 2021   Matthew Giannini  Creation
//

using inet
using web
using [java] javax.net.ssl::SSLSocketFactory

**************************************************************************
** MqttTransport
**************************************************************************

**
** MQTT Transport
**
internal mixin MqttTransport
{
  static MqttTransport open(ClientConfig config)
  {
    switch (config.serverUri.scheme)
    {
      case "mqtt":
      case "mqtts":
        return TcpTransport(config)
      case "ws":
      case "wss":
        return WsTransport(config)
      default:
        throw MqttErr("Unsupported URI scheme: $config.serverUri")
    }
  }

  abstract Void send(Buf msg)

  abstract InStream in()

  abstract Void close()

  abstract Bool isClosed()
}

**************************************************************************
** TcpTransport
**************************************************************************

internal class TcpTransport : MqttTransport
{
  new make(ClientConfig config)
  {
    uri := config.serverUri

    this.socket = uri.scheme == "mqtts"
      ? tlsSocket(config)
      : TcpSocket(config.socketConfig)
    socket.connect(IpAddr(uri.host), uri.port)
  }

  private static TcpSocket tlsSocket(ClientConfig config)
  {
    // TODO:FIXIT - TcpSocket not longer provides a way to make a TLS
    // socket from an existing SSLSocketFactory.
    // factory := config.sslSocketFactory?.val as SSLSocketFactory
    // return factory == null
    //   ? TcpSocket.makeTls()
    //   : TcpSocket.makeRaw(factory.createSocket)
    return TcpSocket(config.socketConfig).upgradeTls
  }

  private TcpSocket socket

  override Void send(Buf msg) { socket.out.writeBuf(msg).flush }

  override InStream in() { socket.in }

  override Void close() { socket.close }

  override Bool isClosed() { socket.isClosed || !socket.isConnected }
}

**************************************************************************
** WsTransport
**************************************************************************

internal class WsTransport : MqttTransport
{
  new make(ClientConfig config)
  {
    this.socket = WebSocket.openClient(config.serverUri, ["Sec-WebSocket-Protocol": "mqtt"])
    this.wsIn   = WsInStream(socket)
  }

  private WebSocket socket
  private WsInStream wsIn

  override Void send(Buf msg) { socket.send(msg) }

  override InStream in() { wsIn }

  override Void close() { socket.close }

  override Bool isClosed() { socket.isClosed }
}

internal class WsInStream : InStream
{
  new make(WebSocket socket)  : super(null)
  {
    this.socket = socket
  }

  private WebSocket socket
  private Buf curFrame := Buf(0)

  private Buf frame()
  {
    if (!curFrame.more) curFrame = socket.receive
    return curFrame
  }

  override Int? read()
  {
    frame.read
  }

  override Int? readBuf(Buf buf, Int n)
  {
    n = n.min(frame.remaining)
    buf.writeBuf(frame, n)
    return n
  }

  override This unread(Int b)
  {
    throw IOErr("Unsupported")
  }
}