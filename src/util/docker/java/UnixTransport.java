//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Oct 2021  Matthew Giannini  Creation
//

package fan.docker;

import fan.sys.*;
import fanx.interop.Interop;

import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;

import java.net.Socket;
import java.net.SocketAddress;
import java.net.SocketException;
import java.nio.channels.Channels;
import java.nio.channels.SocketChannel;
import java.net.URI;
import java.net.URISyntaxException;

/**
 * UnixTransport
 */
final public class UnixTransport extends FanObj implements DockerTransport
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  public static UnixTransport make(final DockerConfig config)
  {
    if (Env.cur().javaVersion() < 17)
    {
      throw IOErr.make("Java 17+ is required to create unix domain sockets: java.version=" + Env.cur().vars().get("java.version"));
    }

    try
    {
      return new UnixTransport(new URI(config.daemonHost).getPath());
    }
    catch (URISyntaxException err)
    {
      throw IOErr.make("Invalid daemon URI", err);
    }
    catch (IOErr ioerr)
    {
      throw ioerr;
    }
    catch (Exception err)
    {
      throw IOErr.make(err);
    }
  }

  private UnixTransport(final String path) throws Exception
  {
    Class<?> unixDomainSocketAddress = Class.forName("java.net.UnixDomainSocketAddress");
    SocketAddress socketAddress =
      (SocketAddress)unixDomainSocketAddress.getMethod("of", String.class)
        .invoke(null, path);
    this.socketChannel = SocketChannel.open(socketAddress);

    this.fanOut = Interop.toFan(Channels.newOutputStream(socketChannel));
    this.fanIn = Interop.toFan(Channels.newInputStream(socketChannel));
  }

  private final SocketChannel socketChannel;
  private final OutStream fanOut;
  private final InStream fanIn;


//////////////////////////////////////////////////////////////////////////
// Type
//////////////////////////////////////////////////////////////////////////

  public final Type typeof() { return typeof; }
  public static final Type typeof = Type.find("docker::UnixTransport");

//////////////////////////////////////////////////////////////////////////
// DockerTransport
//////////////////////////////////////////////////////////////////////////

  public OutStream out()
  {
    return fanOut;
  }

  public InStream in()
  {
    return fanIn;
  }

  public void close()
  {
    try
    {
      socketChannel.close();
    }
    catch (Exception err)
    {
      throw IOErr.make(err);
    }
  }
}