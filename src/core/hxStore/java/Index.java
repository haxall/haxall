//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2016  Brian Frank  Creation
//

package fan.hxStore;

import java.io.BufferedInputStream;
import java.io.DataInputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.RandomAccessFile;
import fan.sys.*;

/**
 * Index stores an entry for each Blob at fixed 56 byte offsets
 */
final class Index
{

//////////////////////////////////////////////////////////////////////////
// Open
//////////////////////////////////////////////////////////////////////////

  static final String fileName = "folio.index";

  static Index open(Store store, File dir, StoreConfig config) throws IOException
  {
    java.io.File file = new java.io.File(((LocalFile)dir).toJava(), fileName);
    boolean exists = file.exists() && file.length() > 0;
    return exists ? read(store, file) : create(store, file);
  }

  private static Index read(Store store, java.io.File file) throws IOException
  {
    // compute number of entries to read from file size
    int numEntries = (int)(file.length() / entrySize) - 1;

    // allocate in-memory map/meta, keep track of max version
    StoreMeta meta = new StoreMeta(store.config);
    BlobMap map = new BlobMap(numEntries);
    long maxVer = 0;

    DataInputStream in = new DataInputStream(new BufferedInputStream(new FileInputStream(file), 4096));
    try
    {
      // read and verify header entry
      byte[] buf = new byte[entrySize];
      in.readFully(buf, 0, entrySize);
      meta.read(buf);

      // read blob entries
      for (int i=0; i<numEntries; ++i)
      {
        // decode blob
        in.readFully(buf, 0, entrySize);
        Blob blob = Blob.indexDecode(store, i, buf);
        if (blob == null) continue;
        map.set(blob);

        // keep track of max ver and used pages
        if (blob.ver > maxVer) maxVer = blob.ver;
        if (blob.isActive()) store.pages.file(blob.fileId).freeMap.markUsed(blob.pageId);
      }
    }
    finally { in.close(); }

    // init store's ver and return Index instance
    return new Index(store, file,meta, map, maxVer);
  }

  private static Index create(Store store, java.io.File file) throws IOException
  {
    // init meta from config
    StoreMeta meta = new StoreMeta(store.config);

    // write out meta header as entry zero
    FileOutputStream out = new FileOutputStream(file);
    out.write(meta.write());
    out.close();

    return new Index(store, file, meta, new BlobMap(1024), 0);
  }

  private Index(Store store, java.io.File file, StoreMeta meta, BlobMap map, long curVer) throws IOException
  {
    this.store   = store;
    this.meta    = meta;
    this.file    = new StoreFile(store, file);
    this.map     = map.reset();
    this.curVer  = curVer;
  }

//////////////////////////////////////////////////////////////////////////
// Methods
//////////////////////////////////////////////////////////////////////////

  final int unflushedCount()
  {
    return file.isDirty() ? 1 : 0;
  }

  void flush() throws IOException
  {
    file.flush();
  }

  void close() throws IOException
  {
    file.close();
  }

  long curVer() { return curVer; }

  synchronized Blob create(Buf meta, Buf data) throws IOException
  {
    long handle = map.allocHandle();
    Blob blob =  new Blob(store, handle, BlobMeta.empty, -1, -1, -1, -1);
    blob.write(meta, data);
    Blob old = map.set(blob);
    return blob;
  }

  synchronized void write(Blob b, BlobMeta meta, int size, int fileId, int pageId, long ver) throws IOException
  {
    // allocate newVer unless it was passed in from push
    if (ver < 0L) ver = nextVer();

    // mutate Blob fields only within my lock
    b.ver    = ver;
    b.meta   = meta;
    b.size   = size;
    b.fileId = fileId;
    b.pageId = pageId;

    // write to index file
    writeEntry(b);
  }

  synchronized void delete(Blob b, long ver) throws IOException
  {
    // allocate newVer unless it was passed in from push
    if (ver < 0L) ver = nextVer();

    // mutate Blob fields only within my lock
    // note: we perserve meta and stash
    b.ver    = ver;
    b.size   = -1;
    b.fileId = -1;
    b.pageId = -1;

    // update map within my lock
    map.free(b);

    // write empty entry to index file
    writeEntry(b);
  }

  synchronized Blob[] snapshot()
  {
    return map.snapshot();
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  static Err err(String msg) { return Store.err(msg); }

  private long nextVer()
  {
    long ver = ++curVer;
    if (ver <= 0L) throw Store.err("Ver rolled over");
    return ver;
  }

  private void writeEntry(Blob b) throws IOException
  {
    b.indexEncode(entryBuf);
    file.write(blobToPos(b), entryBuf, 0, entrySize);
  }

  private static long blobToPos(Blob b)
  {
    long index = (long)BlobMap.handleToIndex(b.handle);
    return (index + 1) * (long)entrySize;
  }

//////////////////////////////////////////////////////////////////////////
// Constants
//////////////////////////////////////////////////////////////////////////

  static final int entrySize = Store.indexEntrySize;

  final Store store;
  final StoreFile file;
  final BlobMap map;
  final StoreMeta meta;
  private byte[] entryBuf = new byte[entrySize];
  private long curVer;
}