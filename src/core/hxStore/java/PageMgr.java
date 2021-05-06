//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Nov 2015  Brian Frank  Creation
//

package fan.hxStore;

import fan.sys.*;
import java.io.IOException;
import java.io.RandomAccessFile;

/**

Page files are sized as follows when filled up:

  Page Size   File Size   Power of 2
  ---------   ---------   ----------
  16B         1MB         4
  32B         2MB         5
  64B         4MB         6
  128B        8MB         7
  256B        16MB        8
  512B        32MB        9
  1KB         64MB        10
  2KB         128MB       11
  4KB         256MB       12
  8KB         512MB       13
  16KB        1GB         14
  32KB        2GB         15
  64KB        4GB         16
  128KB       8GB         17
  256KB       16GB        18
  512KB       32GB        19
  1MB         64GB        20

*/
public class PageMgr
{

//////////////////////////////////////////////////////////////////////////
// Open
//////////////////////////////////////////////////////////////////////////

  public static PageMgr open(Store store, File dir)
  {
    // process each of the sub-directories
    List acc = openPageFiles(store, dir);

    // map page files into array
    PageFile[] files = pageFilesToArray(acc);

    return new PageMgr(store, dir, files);
  }

  private static List openPageFiles(Store store, File dir)
  {
    List acc = List.make(Sys.ObjType, 256);
    List subDirs = dir.list();
    for (int i=0; i<subDirs.sz(); ++i)
    {
      File subDir = (File)subDirs.get(i);
      if (subDir.isDir() && subDir.name().startsWith("data"))
      {
        List subFiles = subDir.list();
        for (int j=0; j<subFiles.sz(); ++j)
        {
          LocalFile f = (LocalFile)subFiles.get(j);
          if (f.name().startsWith("data-"))
            acc.add(openPageFile(store, f));
        }
      }
    }
    return acc;
  }

  private static PageFile openPageFile(Store store, LocalFile f)
  {
    try
    {
      String name = f.name();
      int fileId = fileNameToFileId(name);
      int pageSize = fileNameToPageSize(name);
      return new PageFile(store, fileId, pageSize, f.toJava());
    }
    catch (Exception e)
    {
      throw Store.err("Cannot open page file: " + f, e);
    }
  }

  private static PageFile[] pageFilesToArray(List acc)
  {
    // find max id
    int maxFileId = -1;
    for (int i=0; i<acc.sz(); ++i)
    {
      PageFile f = (PageFile)acc.get(i);
      if (f.fileId > maxFileId) maxFileId = f.fileId;
    }

    // map them into an array
    PageFile[] files = new PageFile[maxFileId+1];
    for (int i=0; i<acc.sz(); ++i)
    {
      PageFile f = (PageFile)acc.get(i);
      if (files[f.fileId] != null) throw err("Duplicate file ids: " + f.fileId);
      files[f.fileId] = f;
    }

    // verify contiguous
    for (int i=0; i<files.length; ++i)
      if (files[i] == null) throw err("Missing page file: " + i);

    return files;
  }

  private PageMgr(Store store, File dir, PageFile[] files)
  {
    this.store = store;
    this.dir = (LocalFile)dir;
    this.files = files;
  }

//////////////////////////////////////////////////////////////////////////
// Methods
//////////////////////////////////////////////////////////////////////////

  final int size()
  {
    return this.files.length;
  }

  final PageFile file(int fileId)
  {
    PageFile[] files = this.files;
    if (0 <= fileId && fileId < files.length)
      return files[fileId];
    else
      throw err("Invalid fileId " + fileId);
  }

  final List distribution()
  {
    int length = toPageSizeCode(Store.maxPageSize) + 1;
    int[] numFiles = new int[length];
    int[] numBlobs = new int[length];
    PageFile[] files = this.files;
    for (int i=0; i<files.length; ++i)
    {
      PageFile file = files[i];
      int index = toPageSizeCode(file.pageSize) - 1;
      numFiles[index] += 1;
      numBlobs[index] += file.freeMap.numUsed();
    }

    List list = List.make(Sys.StrType, length);
    for (int i=0; i<length; ++i)
    {
      if (numFiles[i] == 0) continue;
      list.add("" + (2<<i) + "," + numFiles[i] + "," + numBlobs[i]);
    }
    return list;
  }

  final int unflushedCount()
  {
    int count = 0;
    PageFile[] files = this.files;
    for (int i=0; i<files.length; ++i)
      if (files[i].file.isDirty()) count++;
    return count;
  }

  final void flush() throws IOException
  {
    PageFile[] files = this.files;
    for (int i=0; i<files.length; ++i)
      files[i].file.flush();
  }

  final void close() throws IOException
  {
    PageFile[] files = this.files;
    for (int i=0; i<files.length; ++i)
      files[i].file.close();
  }

  /** Is given page used */
  synchronized boolean isUsed(int fileId, int pageId)
  {
    return file(fileId).freeMap.isUsed(pageId);
  }

  /** Allocate page return fileId in high 4 bytes, pageId in low 4 bytes. */
  synchronized long alloc(int size) throws IOException
  {
    // size checks
    if (size > Store.maxPageSize) throw err("Data size exceeds max page size: " + size);

    // compute best fit page size
    int pageSize = Store.minPageSize;
    while (size > pageSize) pageSize <<= 1;

    // find page file that best fits this size and has room
    for (int i=0; i<files.length; ++i)
    {
      PageFile file = files[i];
      if (pageSize == file.pageSize)
      {
        int pageId = file.freeMap.alloc();
        if (pageId >= 0) return IO.join(file.fileId, pageId);
      }
    }

    // allocate new page file
    int fileId = files.length;
    if (fileId > Store.maxPageFileId) throw err("Too many page files: " + fileId);

    // open random access
    PageFile file = new PageFile(store, fileId, pageSize, toFile(fileId, pageSize));

    // grow files array and map new file
    PageFile[] temp = new PageFile[fileId + 1];
    System.arraycopy(files, 0, temp, 0, files.length);
    files = temp;
    files[fileId] = file;

    // alloc first page from newly minted file
    int pageId = file.freeMap.alloc();
    return IO.join(fileId, pageId);
  }

  /** Free given page */
  synchronized void free(int fileId, int pageId)
  {
    // if we have a GC freeze, then just queue it
    if (gcQueue != null)
      gcQueue.add(new PageAddr(fileId, pageId));
    else
      file(fileId).freeMap.free(pageId);
  }

  /** For debugging only, not synchronized */
  int gcFreezeCount() { return gcFreezeCount; }

  /** Garbage collection freeze */
  synchronized void gcFreeze()
  {
    gcFreezeCount++;
    if (gcQueue == null) gcQueue = new List(Sys.ObjType, 64);
  }

  /** Garbage collection unfreeze */
  synchronized void gcUnfreeze()
  {
    if (gcFreezeCount <= 0) throw Err.make("Not in gcFreeze");

    gcFreezeCount--;
    if (gcFreezeCount > 0) return;

    // free anything in the GC queue and null out the queue
    List q = gcQueue;
    gcQueue = null;
    for (int i=0; i<q.sz(); ++i)
    {
      PageAddr addr = (PageAddr)q.get(i);
      free(addr.fileId, addr.pageId);
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  static int fileNameToFileId(String name)
  {
    return Integer.parseInt(name.substring(5, 8)) * 1000 +
           Integer.parseInt(name.substring(9, 12));
  }

  static int fileNameToPageSize(String name)
  {
    return 1 << Integer.parseInt(name.substring(14, 16));
  }

  java.io.File toFile(int fileId, int pageSize)
  {
    // ensure sub-directory is created
    java.io.File subDir = new java.io.File(dir.toJava(), toFileDir(fileId, pageSize));
    subDir.mkdir();

    // return file
    String fileName = toFileName(fileId, pageSize);
    java.io.File f = new java.io.File(subDir, fileName);
    return f;
  }

  static String toFileDir(int fileId, int pageSize)
  {
    // format as dir/dataXXX/data-XXX-YYY.pZZ
    return "data" + intToPadStr(fileId / 1000);
  }

  static String toFileName(int fileId, int pageSize)
  {
    // format as dir/dataXXX/data-XXX-YYY.pZZ
    String dirNum = intToPadStr(fileId / 1000);
    String fileNum = intToPadStr(fileId % 1000);

    // format pageSize as multiple of 2
    String sizeCode = String.valueOf(toPageSizeCode(pageSize));
    if (sizeCode.length() < 2) sizeCode = "0"+sizeCode;

    return "data-" + dirNum + "-" + fileNum + ".p" + sizeCode;
  }

  static String intToPadStr(int x)
  {
    String s = String.valueOf(x);
    if (s.length() == 1) return "00" + s;
    if (s.length() == 2) return "0" + s;
    if (s.length() == 3) return s;
    throw err("intToPadStr: " + x);
  }

  static int toPageSizeCode(int pageSize)
  {
    int pow = 4;
    while (pow < 32)
    {
      if (pageSize == 1 << pow) return pow;
      pow++;
    }
    throw err("Invalid page size: " + pageSize);
  }

  static Err err(String msg) { return Store.err(msg); }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  void debugFiles(OutStream out)
  {
    for (int i=0; i<files.length; ++i)
      if (files[i] != null)
        out.printLine(files[i].debug());
  }

//////////////////////////////////////////////////////////////////////////
// PageAddr
//////////////////////////////////////////////////////////////////////////

  static class PageAddr
  {
    PageAddr(int fileId, int pageId) { this.fileId = fileId; this.pageId = pageId; }
    final int fileId;
    final int pageId;
  }

//////////////////////////////////////////////////////////////////////////
// PageFile
//////////////////////////////////////////////////////////////////////////

  static class PageFile
  {
    PageFile(Store store, int fileId, int pageSize, java.io.File file) throws IOException
    {
      this.fileId   = fileId;
      this.pageSize = pageSize;
      this.file     = new StoreFile(store, file);
      this.freeMap  = new FreeMap(Store.pagesPerFile);
    }

    synchronized void read(int pageId, byte[] buf, int offset, int size) throws IOException
    {
      file.read(pagePos(pageId), buf, offset, size);
    }

    synchronized void write(int pageId, byte[] buf, int offset, int size) throws IOException
    {
      file.write(pagePos(pageId), buf, offset, size);
    }

    synchronized void append(int pageId, int offset, byte[] buf, int size) throws IOException
    {
      if (offset + size > pageSize) throw err("Invalid append: " + offset + " + " + size + " > " + pageSize);
      file.write(pagePos(pageId)+offset, buf, 0, size);
    }

    long pagePos(int pageId) { return (long)pageId * (long)pageSize; }

    public String debug()
    {
      long fileSize = file.size();
      return FanStr.padl(""+fileId, 3) + ": " + FanStr.padl(debugSize(fileSize), 6) + " / " + FanStr.padr(debugSize(pageSize), 5) + " = " + FanStr.padl(""+fileSize/pageSize, 5) + " pages";
    }

    private static String debugSize(long size)
    {
      if (size < 1024) return ""+size;
      if (size < 1024*1024) return (size/1024L) + "KB";
      return (size/1024L/1024L) + "MB";
    }

    final int fileId;            // file id (index into files)
    final int pageSize;          // bytes in each data page
    final StoreFile file;        // backing file
    final FreeMap freeMap;       // bitmap for used vs free pages (must go thru PageMgr)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private final Store store;
  private final LocalFile dir;
  private PageFile[] files;
  private List gcQueue;
  private int gcFreezeCount;
}