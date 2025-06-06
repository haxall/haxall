//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2016  Brian Frank  Creation
//

package fan.hxStore;

import fan.sys.*;
import java.util.zip.CRC32;

/**
 * BlobMeta
 */
public final class BlobMeta extends FanObj
{
  static final BlobMeta empty = new BlobMeta(new byte[0]);

  public static BlobMeta fromBuf(Buf buf)
  {
    if (buf.isEmpty()) return empty;
    return new BlobMeta(buf.constArray());
  }

  BlobMeta(byte[] buf)
  {
    this.buf = buf;
  }

  public final Type typeof() { return typeof; }

  public static Type typeof$() { return typeof; }
  private static final Type typeof = Type.find("hxStore::BlobMeta");

  public final long size()
  {
    return buf.length;
  }

  final int sz()
  {
    return buf.length;
  }

  public final long get(long index)
  {
    return buf[(int)index] & 0xFF;
  }

  public final long readU1(long index)
  {
    return buf[(int)index] & 0xFF;
  }

  public final long readU2(long index)
  {
    int i = (int)index;
    return ((buf[i] & 0xFF) << 8) |
            (buf[i+1] & 0xFF);
  }

  public final long readU4(long index)
  {
    int i = (int)index;
    int v = ((buf[i]   & 0xFF) << 24) |
            ((buf[i+1] & 0xFF) << 16) |
            ((buf[i+2] & 0xFF) << 8)  |
             (buf[i+3] & 0xFF);
    return (long)v & 0xFFFFFFFFL;
  }

  public final long readS1(long index)
  {
     return buf[(int)index];
  }

  public final long readS2(long index)
  {
    int i = (int)index;
    return (short)((buf[i] & 0xFF) << 8) |
                   (buf[i+1] & 0xFF);
  }

  public final long readS4(long index)
  {
    int i = (int)index;
    int v = ((buf[i]   & 0xFF) << 24) |
            ((buf[i+1] & 0xFF) << 16) |
            ((buf[i+2] & 0xFF) << 8)  |
             (buf[i+3] & 0xFF);
    return v;
  }

  public final long readS8(long index)
  {
    return (readU4(index) << 32) | readU4(index+4);
  }

  public String toStr()
  {
    StringBuffer s = new StringBuffer(2 + buf.length*2);
    s.append("0x");
    for (int i=0; i<buf.length; ++i)
    {
      int b = buf[i] & 0xFF;
      if (b < 0x10) s.append("0");
      s.append(Integer.toHexString(b));
    }
    return s.toString();
  }

  public int crc()
  {
    CRC32 crc =  new CRC32();
    crc.update(buf, 0, buf.length);
    return (int)crc.getValue();
  }

  final byte[] buf;
}

