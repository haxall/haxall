//
// Copyright (c) 2017, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Feb 2017  Matthew Giannini  Creation
//

package fan.ftp;

import fan.sys.*;
import fan.inet.TcpSocket;
import fan.inet.TcpSocketPeer;

import java.security.*;
import javax.net.ssl.*;

public class FtpClientPeer
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  public static FtpClientPeer make(FtpClient self)
  {
    return new FtpClientPeer();
  }

//////////////////////////////////////////////////////////////////////////
// FtpClient
//////////////////////////////////////////////////////////////////////////

  public TcpSocket openSecureDataChannel(FtpClient self, TcpSocket cmd, TcpSocket data)
  {
    try
    {
      final SSLSocketFactory factory = cmd.peer.getSslContext().getSocketFactory();

      // upgrade data socket to TLS
      final SSLSocket socket = (SSLSocket)factory.createSocket(
        data.peer.socket(),
        data.peer.socket().getInetAddress().getHostAddress(),
        data.peer.socket().getPort(),
        false);

      // Force data socket to reuse TLS session from cmd socket, even though
      // they aren't on the same port. This is truly horrific.
      // http://eng.wealthfront.com/2016/06/10/connecting-to-an-ftps-server-with-ssl-session-reuse-in-java-7-and-8/
      final SSLSession session = ((SSLSocket)cmd.peer.socket()).getSession();
      final SSLSessionContext context = session.getSessionContext();
      final java.lang.reflect.Field sessionHostPortCache = context.getClass().getDeclaredField("sessionHostPortCache");
      sessionHostPortCache.setAccessible(true);
      final Object cache = sessionHostPortCache.get(context);
      final java.lang.reflect.Method putMethod = cache.getClass().getDeclaredMethod("put", Object.class, Object.class);
      putMethod.setAccessible(true);
      java.lang.reflect.Method getHostMethod;
      try
      {
        getHostMethod = socket.getClass().getDeclaredMethod("getPeerHost");
      }
      catch (NoSuchMethodException e)
      {
        // older versions of java have this method name
        getHostMethod = socket.getClass().getDeclaredMethod("getHost");
        getHostMethod.setAccessible(true);
      }
      Object host = getHostMethod.invoke(socket);
      final String key = String.format("%s:%s", host, String.valueOf(socket.getPort())).toLowerCase(java.util.Locale.ROOT);
      putMethod.invoke(cache, key, session);

      // initialize socket
      socket.setUseClientMode(true);
      socket.startHandshake();

      // return secure data channel
      return TcpSocket.makeRaw(socket);
    }
    catch (Exception e)
    {
      throw IOErr.make(e);
    }
  }
}