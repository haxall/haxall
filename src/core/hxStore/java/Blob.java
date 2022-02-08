//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2016  Brian Frank  Creation
//

package fan.hxStore;

import java.io.IOException;
import fan.sys.*;

/**
 * Blob
 */
public final class Blob extends FanObj
{
  Blob(Store store, long handle, BlobMeta meta, long ver, int size, int fileId, int pageId)
  {
    this.store  = store;
    this.handle = handle;
    this.meta   = meta;
    this.ver    = ver;
    this.size   = size;
    this.fileId = fileId;
    this.pageId = pageId;
  }

  Blob(long handle) { this.store = null; this.handle = handle; } // just for testing

  public final Type typeof() { return typeof; }
  static final Type typeof = Type.find("hxStore::Blob");

  public final Store store() { return store; }

  public final long handle() { return handle; }

  public final BlobMeta meta() { return meta; }

  public final long ver() { return ver; }

  public final long size() { return size; }

  public boolean isActive() { return size >= 0; }

  public boolean isDeleted() { return size < 0; }

  final long fileId() { return fileId; }

  final long pageId() { return pageId; }

  public String locToStr() { return fileId + ":" + pageId; }

  public final Object stash() { return stash; }

  public final void stash(Object v)
  {
    if (!FanObj.isImmutable(v)) throw NotImmutableErr.make(v.toString());
    this.stash = v;
  }

  public String toStr() { return handleToStr(handle); }

  public static String handleToStr(long h)
  {
    return Long.toHexString(((h >> 32) & 0xFFFFFFFFL)) + "." +
           Long.toHexString(h & 0xFFFFFFFFL);
  }

  public static long handleFromStr(String s)
  {
    try
    {
      int dot = s.indexOf('.');
      String a = s.substring(0, dot);
      String b = s.substring(dot+1, s.length());
      return Long.valueOf(a, 16) << 32 | Long.valueOf(b, 16);
    }
    catch (Exception e)
    {
      throw ParseErr.make("Invalid blob handle string: " + s);
    }
  }

//////////////////////////////////////////////////////////////////////////
// I/O
//////////////////////////////////////////////////////////////////////////

  public synchronized Buf read(Buf buf)
  {
    checkRead();
    try
    {
      // get raw byte[] data and ensure capacity
      MemBuf b = (MemBuf)buf;
      if (b.capacity() < size) b.capacity(size);

      // read data page
      store.pages.file(fileId).read(pageId, b.buf, 0, size);

      // reset buf pos/size
      b.pos = 0;
      b.size = size;
      return b;
    }
    catch (IOException e)
    {
      throw Store.err(e);
    }
  }

  public synchronized void write(Buf meta, Buf data)
  {
    checkWrite();
    doWrite(meta, data, -1L);
  }

  public synchronized void write(Buf meta, Buf data, long expectedVer)
  {
    // this.ver is mutated holding the Index lock, but for both
    // write/append we also have the Blob lock, so we can just
    // check first thing here
    if (expectedVer > 0 && this.ver != expectedVer)
      throw ConcurrentWriteErr.make("Current ver: " + this.ver + " != " + expectedVer);

    write(meta, data);
  }

  void doWrite(Buf meta, Buf data, long newVer)
  {
    if (meta != null) Store.checkMeta(this, meta);
    if (data != null) Store.checkDataSize(this, data.sz());
    try
    {
      int oldFileId = this.fileId;
      int oldPageId = this.pageId;
      BlobMeta newMeta = this.meta;
      int newSize = this.size;
      int newFileId = oldFileId;
      int newPageId = oldPageId;

      // write data page
      if (data != null)
      {
        newSize = data.sz();
        long loc = store.pages.alloc(newSize);
        newFileId = IO.hi4(loc);
        newPageId = IO.lo4(loc);
        if (store.testDiskFull) throw new IOException("Disk full test");
        store.pages.file(newFileId).write(newPageId, data.unsafeArray(), data.unsafeOffset(), newSize);
      }

      // update meta
      if (meta != null)
      {
        newMeta = BlobMeta.fromBuf(meta);
      }

      // update my indexing fields and index file entry
      store.index.write(this, newMeta, newSize, newFileId, newPageId, newVer);

      // free old data page
      if (data != null && oldFileId >= 0)
      {
        store.pages.free(oldFileId, oldPageId);
      }
    }
    catch (IOException e)
    {
      throw store.errWrite(e);
    }
  }

  public synchronized void append(Buf meta, Buf data)
  {
    // if this append forces us to a larger page size
    // then we need to rewrite the entire page
    int newSize = this.size + data.sz();
    if (newSize > store.pages.file(fileId).pageSize)
    {
      Buf mergeBuf = MemBuf.make(newSize);
      read(mergeBuf);
      mergeBuf.seek(this.size).writeBuf(data.seek(0));
      write(meta, mergeBuf);
      return;
    }

    // otherwise we can write it in-place
    checkWrite();
    if (meta != null) Store.checkMeta(this, meta);
    Store.checkDataSize(this, newSize);
    try
    {
      // append data into existing page block
      MemBuf d = (MemBuf)data;
      int offset = this.size;
      if (store.testDiskFull) throw new IOException("Disk full test");
      store.pages.file(fileId).append(pageId, offset, d.buf, d.size);

      // update my meta
      BlobMeta newMeta = this.meta;
      if (meta != null)
      {
        newMeta = BlobMeta.fromBuf(meta);
      }

      // update my indexing fields and index file entry
      store.index.write(this, newMeta, newSize, this.fileId, this.pageId, -1L);
    }
    catch (IOException e)
    {
      throw store.errWrite(e);
    }
  }

  public synchronized void delete()
  {
    checkWrite();
    delete(-1L);
  }

  void delete(long newVer)
  {
    try
    {
      int oldFileId = this.fileId;
      int oldPageId = this.pageId;

      // zero out my indexing fields and disk entry
      store.index.delete(this, newVer);

      // free page
      store.pages.free(oldFileId, oldPageId);
    }
    catch (IOException e)
    {
      throw store.errWrite(e);
    }
  }

  private void checkRead()
  {
    if (fileId < 0 && ver >= 0) throw Store.err("Blob is deleted");
    store.checkRead();
  }

  private void checkWrite()
  {
    if (fileId < 0 && ver >= 0) throw Store.err("Blob is deleted");
    store.checkWrite();
  }

//////////////////////////////////////////////////////////////////////////
// Indexing (must be holding Index lock)
//////////////////////////////////////////////////////////////////////////

  static Blob indexDecode(Store store, int index, byte[] buf)
  {
    int handleHi  = IO.read4(buf, 0);
    int metaSize  = IO.read1(buf, 5);
    BlobMeta meta = IO.readMeta(buf, 6, metaSize);
    long ver      = IO.read8(buf, 38);
    int size      = IO.read4(buf, 46);
    int fileId    = IO.read4(buf, 50);
    int pageId    = IO.read2(buf, 54);

    if (handleHi == 0)
    {
      if (ver == 0) return null;
      return new Blob(store, index, BlobMeta.empty, ver, -1, -1, -1);
    }

    long handle = IO.join(handleHi, index);
    return new Blob(store, handle, meta, ver, size, fileId, pageId);
  }

  byte[] indexEncode(byte[] buf) throws IOException
  {
    if (isDeleted())
    {
      IO.write4(buf,  0, 0);
      IO.write1(buf,  5, 0);
      IO.writeZ(buf,  6, 32);
      IO.write8(buf, 38, ver);
      IO.write4(buf, 46, 0);
      IO.write4(buf, 50, 0);
      IO.write2(buf, 54, 0);
    }
    else
    {
      IO.write4(buf,  0, IO.hi4(handle));
      IO.write1(buf,  5, meta.buf.length);
      IO.writeN(buf,  6, meta.buf, meta.buf.length);
      IO.write8(buf, 38, ver);
      IO.write4(buf, 46, size);
      IO.write4(buf, 50, fileId);
      IO.write2(buf, 54, pageId);
    }
    return buf;
  }

  Blob snapshot()
  {
    return new Blob(null, handle, meta, ver, size, fileId, pageId);
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  // All fields must be mutated within Index lock

  final Store store;    // associated store
  final long handle;    // unique identifier
  BlobMeta meta;        // meta data bytes
  long ver;             // current journal version
  int size;             // size of data page in bytes
  int fileId;           // data page fileId
  int pageId;           // data page pageId
  Object stash;         // application data
}