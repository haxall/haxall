//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Apr 2016  Brian Frank  Creation
//

package fan.hxStore;

import fan.sys.*;

/**
 * StoreMeta
 */
public final class StoreMeta extends FanObj
{
  /** Default from config */
  StoreMeta(StoreConfig config)
  {
    this.hisPageSize = config.hisPageSize;
  }

  /** Write header encoded into entry zero */
  byte[] write()
  {
    byte[] buf = new byte[Store.indexEntrySize];
    IO.write8(buf,  0, Store.indexMagic);
    IO.write4(buf,  8, Store.indexVersion);
    IO.write8(buf, 12, hisPageSize.ticks());
    return buf;
  }

  /** Read header encoded into entry zero */
  void read(byte[] buf)
  {
    long magic = IO.read8(buf, 0);
    int version = IO.read4(buf, 8);
    long hisPageSize = IO.read8(buf, 12);

    if (magic != Store.indexMagic) throw err("Invalid magic 0x" + Long.toHexString(magic));
    if (version != Store.indexVersion) throw err("Invalid magic 0x" + Integer.toHexString(version));
    if (hisPageSize < 3600000000000L) throw err("Invalid hisPageSize: " + hisPageSize);

    this.hisPageSize = Duration.make(hisPageSize);
  }

  static Err err(String msg) { return StoreErr.make(msg); }

  public final Type typeof() { return typeof; }
  private static final Type typeof = Type.find("hxStore::StoreMeta");

  public final long blobMetaMax() { return Store.maxMetaSize; }

  public final long blobDataMax() { return Store.maxPageSize; }

  public final Duration hisPageSize() { return hisPageSize; }

  private Duration hisPageSize;
}