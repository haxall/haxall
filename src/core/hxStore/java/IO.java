//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2016  Brian Frank  Creation
//

package fan.hxStore;

import fan.sys.*;

/**
 * IO utilities
 */
final class IO
{

//////////////////////////////////////////////////////////////////////////
// Reads
//////////////////////////////////////////////////////////////////////////

  static int read1(byte[] buf, int i)
  {
    return buf[i] & 0xFF;
  }

  static int read2(byte[] buf, int i)
  {
    return ((buf[i] & 0xFF) << 8) |
            (buf[i+1] & 0xFF);
  }

  static int read4(byte[] buf, int i)
  {
    return ((buf[i]   & 0xFF) << 24) |
           ((buf[i+1] & 0xFF) << 16) |
           ((buf[i+2] & 0xFF) << 8)  |
            (buf[i+3] & 0xFF);
  }

  static long read8(byte[] buf, int i)
  {
    return join(read4(buf, i), read4(buf, i+4));
  }

  static BlobMeta readMeta(byte[] buf, int i, int len)
  {
    if (len == 0) return BlobMeta.empty;
    byte[] temp = new byte[len];
    System.arraycopy(buf, i, temp, 0, len);
    return new BlobMeta(temp);
  }

//////////////////////////////////////////////////////////////////////////
// Writes
//////////////////////////////////////////////////////////////////////////

  static void write1(byte[] buf, int i, int val)
  {
    buf[i] = (byte)val;
  }

  static void write2(byte[] buf, int i, int val)
  {
    buf[i]   = (byte)((val >> 8) & 0xFF);
    buf[i+1] = (byte)(val & 0xFF);
  }

  static void write4(byte[] buf, int i, int val)
  {
    buf[i]   = (byte)((val >> 24) & 0xFF);
    buf[i+1] = (byte)((val >> 16) & 0xFF);
    buf[i+2] = (byte)((val >> 8) & 0xFF);
    buf[i+3] = (byte)(val & 0xFF);
  }

  static void write8(byte[] buf, int i, long val)
  {
    buf[i]   = (byte)((val >> 56) & 0xFF);
    buf[i+1] = (byte)((val >> 48) & 0xFF);
    buf[i+2] = (byte)((val >> 40) & 0xFF);
    buf[i+3] = (byte)((val >> 32) & 0xFF);
    buf[i+4] = (byte)((val >> 24) & 0xFF);
    buf[i+5] = (byte)((val >> 16) & 0xFF);
    buf[i+6] = (byte)((val >> 8) & 0xFF);
    buf[i+7] = (byte)(val & 0xFF);
  }

  static void writeN(byte[] buf, int i, byte[] src, int len)
  {
    System.arraycopy(src, 0, buf, i, len);
  }

  static void writeZ(byte[] buf, int i, int len)
  {
    for (int j=0; j<len; ++j)
      buf[i+j] = 0;
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  static long join(int hi, int lo)
  {
    return (((long)hi & 0xFFFFFFFFL) << 32) | ((long)lo & 0xFFFFFFFFL);
  }

  static int hi4(long v) { return (int)((v >> 32) & 0xFFFFFFFFL); }

  static int lo4(long v) { return (int)(v & 0xFFFFFFFFL); }

}