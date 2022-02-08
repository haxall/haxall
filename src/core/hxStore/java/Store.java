//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2016  Brian Frank  Creation
//

package fan.hxStore;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import fan.sys.*;

/**
 * Store
 */
public final class Store extends FanObj
{
  public static Store open(File dir) { return open(dir, null); }
  public static Store open(File dir, StoreConfig config)
  {
    try
    {
      // verify directory and ensure it exists
      if (!dir.isDir()) throw err("Not a dir: " + dir);
      dir.create();

      // acquire lock file
      LockFile lockFile = LockFile.make(dir.plus(Uri.fromStr("db.lock")));
      lockFile.acquire();

      // create config if null
      if (config == null) config = StoreConfig.make();

      // construct instance
      return new Store(dir, lockFile, config);
    }
    catch (IOException e)
    {
      throw err(e);
    }
  }

  Store(File dir, LockFile lockFile, StoreConfig config) throws IOException
  {
    this.dir      = dir;
    this.lockFile = lockFile;
    this.config   = config;
    this.pages    = PageMgr.open(this, dir);
    this.index    = Index.open(this, dir, config);
    this.meta     = index.meta;
    this.map      = index.map;
  }

//////////////////////////////////////////////////////////////////////////
// Store
//////////////////////////////////////////////////////////////////////////

  public final StoreMeta meta() { return meta; }

  public final File dir() { return dir; }

  public final long ver() { return index.curVer(); }

  public final LockFile lockFile() { return lockFile; }

  public final Type typeof() { return typeof; }
  private static final Type typeof = Type.find("hxStore::Store");

  public final String toStr() { return "Store[" + dir + "]"; }

  public final long size() { return map.size(); }

  public final long gcFreezeCount() { return pages.gcFreezeCount(); }

  public final boolean ro() { return ro; }
  public final void ro(boolean it) { ro = it; }

  public final Func onWriteErr() { return onWriteErr; }
  public final void onWriteErr(Func it) { onWriteErr = it; }

  public final boolean testDiskFull() { return testDiskFull; }
  public final void testDiskFull(boolean it) { testDiskFull= it; }

  public final Blob blob(long handle) { return map.get(handle, true); }
  public final Blob blob(long handle, boolean checked) { return map.get(handle, checked); }

  public final void each(Func f) { map.each(f); }

  public final Blob create(Buf meta, Buf data)
  {
    try
    {
      return index.create(meta, data);
    }
    catch (IOException e)
    {
      throw errWrite(e);
    }
  }

  public final boolean isUsed(long fileId, long pageId)
  {
    return pages.isUsed((int)fileId, (int)pageId);
  }

  public final String flushMode() { return nosync ? "nosync" : "fsync"; }
  public final void flushMode(String it)
  {
    switch (it)
    {
      case "fsync":  nosync = false; break;
      case "nosync": nosync = true;  break;
      default:       throw ArgErr.make("Invalid flushMode: " + it);
    }
  }

  public final long unflushedCount()
  {
    return index.unflushedCount() +  pages.unflushedCount();
  }

  public final void flush()
  {
    try
    {
      pages.flush();
      index.flush();
    }
    catch (IOException e)
    {
      throw err(e);
    }
  }

  public final void close()
  {
    try
    {
      closed = true;
      pages.close();
      index.close();
      lockFile.release();
    }
    catch (IOException e)
    {
      throw err(e);
    }
  }

  public final BackupMonitor backup() { return backup(null, null); }
  public final BackupMonitor backup(File file) { return backup(file, null); }
  public final BackupMonitor backup(File file, Map opts)
  {
    if (file == null) return (BackupMonitor)backupRef.get();

    if (opts == null) opts = new Map(Sys.StrType, Sys.ObjType);

    BackupMonitor backup = new BackupMonitor(this, file, opts);
    if (!backupRef.compareAndSet(null, backup))
      throw err("A backup operation is already in progress");
    else
      return backup.spawn();
  }

  public final void debugFiles(OutStream out)
  {
    pages.debugFiles(out);
  }

  public final long pageFileSize() { return pages.size(); }

  public final List pageFileDistribution() { return pages.distribution(); }

  public final long deletedSize() { return map.deletedSize(); }

  public final Blob deletedBlob(long handle) { return map.deletedGet(handle, true); }
  public final Blob deletedBlob(long handle, boolean checked) { return map.deletedGet(handle, checked); }

  public final void deletedEach(Func f) { map.deletedEach(f); }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  void checkRead()
  {
    if (closed) throw err("Store is closed");
  }

  void checkWrite()
  {
    if (closed) throw err("Store is closed");
    if (ro) throw err("Store is readonly");
  }

  void checkPush()
  {
    if (closed) throw err("Store is closed");
    if (!ro) throw err("Store must be readonly to push");
  }

  static void checkMeta(Blob blob, Buf buf)
  {
    if (buf.sz() > maxMetaSize)
      throw err("Meta size exceeds limit: " + buf.sz() + " > 32 bytes [" + blobToDebugStr(blob) + "]");
  }

  static void checkDataSize(Blob blob, int size)
  {
    if (size > maxPageSize)
      throw err("Data size exceeds limit: " + size + " > 1MB [" + blobToDebugStr(blob) + "]");
  }

  static String blobToDebugStr(Blob b)
  {
    return Blob.handleToStr(b.handle);
  }

  static Err err(String msg) { return StoreErr.make(msg); }

  static Err err(String msg, Throwable cause) { return StoreErr.make(msg, Err.make(cause)); }

  static Err err(Exception cause) { return Err.make(cause); }

  Err errWrite(Exception cause)
  {
    Err err = Err.make(cause);
    if (onWriteErr != null) onWriteErr.call(err);
    return err;
  }

//////////////////////////////////////////////////////////////////////////
// Constants
//////////////////////////////////////////////////////////////////////////

  static final int maxNumBlobs = 1000000000;          // 1 billion blob recs
  static final int maxPageFileId = 999999;            // 999,999 page files
  static final int maxMetaSize = 32;                  // 32 bytes
  static final int minPageSize = 16;                  // 16 bytes min
  static final int maxPageSize = 0x100000;            // 1 MB max
  static final int pagesPerFile = 0x10000;            // 64K pages in each page file
  static final int indexEntrySize = 56;               // blob entry in index file
  static final long indexMagic = 0x666f6c696f53746fL; // "folioSto"
  static final int indexVersion = 0x0003000;          // version 3.0

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  final File dir;
  final LockFile lockFile;
  final StoreConfig config;
  final Index index;
  final BlobMap map;
  final PageMgr pages;
  final StoreMeta meta;
  private boolean closed;
  private boolean ro;
  private Func onWriteErr;
  final AtomicReference backupRef = new AtomicReference();
  boolean testDiskFull;
  boolean nosync;
}