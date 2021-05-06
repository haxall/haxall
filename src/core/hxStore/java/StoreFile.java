//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Dec 2018  Brian Frank  Creation
//

package fan.hxStore;

import java.io.IOException;
import java.io.File;
import java.io.RandomAccessFile;
import fan.sys.*;

/**
 * StoreFile manages all low level file I/O for both index and page files
 */
final class StoreFile
{

  StoreFile(Store store, java.io.File file) throws IOException
  {
    this.store = store;
    this.file  = file;
    this.fp    = new RandomAccessFile(file, "rw");
  }

  boolean isDirty()
  {
    return isDirty;
  }

  long size()
  {
    return file.length();
  }

  void read(long pos, byte[] buf, int offset, int size) throws IOException
  {
    fp.seek(pos);
    fp.readFully(buf, offset, size);
  }

  void write(long pos, byte[] buf, int offset, int size) throws IOException
  {
    fp.seek(pos);
    fp.write(buf, offset, size);
    if (store.nosync)
      isDirty = true;
    else
      fp.getFD().sync();
  }

  void flush() throws IOException
  {
    if (isDirty)
    {
      fp.getFD().sync();
      isDirty = false;
    }
  }

  void close() throws IOException
  {
    fp.close();
  }

  private final Store store;
  private final File file;
  private final RandomAccessFile fp;
  private boolean isDirty;
}