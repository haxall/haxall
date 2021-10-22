//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Oct 2021  Matthew Giannini  Creation
//

package fan.docker;

import fan.sys.*;
import fanx.interop.Interop;

import java.io.InputStream;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.io.IOException;

import java.net.URI;
import java.net.URISyntaxException;

/**
 * WinTransport
 */
final public class WinTransport extends FanObj implements DockerTransport
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  public static WinTransport make(final DockerConfig config)
  {
    try
    {
      return new WinTransport(new URI(config.daemonHost).getPath());
    }
    catch (URISyntaxException err)
    {
      throw IOErr.make("Invalid daemon URI", err);
    }
    catch (Exception err)
    {
      throw IOErr.make(err);
    }
  }

  private WinTransport(final String path) throws Exception
  {
    this.file   = new RandomAccessFile(path, "rw");

    // NOTE: create these once. I observed that creating a new input
    // stream each time causes reading operations to fail after first input
    // stream returned.
    this.fanOut = Interop.toFan(new RafOutputStream());
    this.fanIn  = Interop.toFan(new RafInputStream());
  }

  private final RandomAccessFile file;
  private final OutStream fanOut;
  private final InStream fanIn;

//////////////////////////////////////////////////////////////////////////
// Type
//////////////////////////////////////////////////////////////////////////

  public final Type typeof() { return typeof; }
  public static final Type typeof = Type.find("docker::WinTransport");

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
      file.close();
    }
    catch (IOException err)
    {
      throw IOErr.make(err);
    }
  }

//////////////////////////////////////////////////////////////////////////
// RafOutputStream
//////////////////////////////////////////////////////////////////////////

  private class RafOutputStream extends OutputStream
  {
    public void write(int b) throws IOException
    {
      file.writeByte(b);
    }
    public void close() throws IOException
    {
      file.close();
    }
  }

//////////////////////////////////////////////////////////////////////////
// RafInputStream
//////////////////////////////////////////////////////////////////////////

  private class RafInputStream extends InputStream
  {
    public int read() throws IOException
    {
      return file.read();
    }
    public int read(byte[] b, int off, int len) throws IOException
    {
      return file.read(b, off, len);
    }
    public void close() throws IOException
    {
      file.close();
    }
  }
}
