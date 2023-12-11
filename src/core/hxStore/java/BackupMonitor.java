//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jun 2016  Brian Frank  Creation
//

package fan.hxStore;

import java.io.BufferedOutputStream;
import java.io.FileOutputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import fan.sys.*;
import fan.concurrent.*;

/**
 * BackupMonitor
 */
public final class BackupMonitor extends FanObj
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  BackupMonitor(Store store, File file, Map opts)
  {
    this.store      = store;
    this.file       = file;
    this.buf        = new byte[Store.maxPageSize];
    this.zeros      = new byte[Store.maxPageSize/2];
    this.startTime  = DateTime.now();
    this.opts       = (Map)opts.toImmutable();
    this.pathPrefix = initPathPrefix(this.opts);
    this.future     = Future.makeCompletable();
  }

  private static String initPathPrefix(Map opts)
  {
    String val = Opts.getStr(opts, "pathPrefix", "db-backup/");
    if (!val.endsWith("/")) val = val + "/";
    return val;
  }

//////////////////////////////////////////////////////////////////////////
// Fantom API
//////////////////////////////////////////////////////////////////////////

  public final Type typeof() { return typeof; }
  private static final Type typeof = Type.find("hxStore::BackupMonitor");

  public final Store store() { return store; }

  public final File file() { return file; }

  public final Future future() { return future; }

  public final synchronized boolean isComplete() { return isComplete; }

  public final synchronized long progress() { return progress; }

  public final synchronized DateTime startTime() { return startTime; }

  public final synchronized DateTime endTime() { return endTime; }

  public final synchronized Err err() { return err; }

  public final synchronized void onComplete(Func f) { onComplete = f; }

//////////////////////////////////////////////////////////////////////////
// Spawn
//////////////////////////////////////////////////////////////////////////

  BackupMonitor spawn()
  {
    Runnable runnable = new Runnable() { public void run() { doRun(); } };
    Thread thread = new Thread(runnable, "hxStore.backup");
    thread.start();
    return this;
  }

  void doRun()
  {
    // setup
    store.pages.gcFreeze();

    try
    {
      // pipeline
      findAuxFiles();
      initProgressTotal();
      openFile();
      writeBackupMeta();
      snapshotIndex();
      testDelay();
      writePageFiles();
      writeIndex();
      writeAuxFiles();
      closeFile();
    }
    catch (Throwable e)
    {
      // error
      this.err = Err.make(e);
      try { closeFile(); file.delete(); } catch (Throwable e2) {}
    }

    // cleanup
    store.pages.gcUnfreeze();
    store.backupRef.set(null);

    // update completeion fields
    synchronized (this)
    {
      this.isComplete = true;
      this.progress   = 100;
      this.endTime    = DateTime.now();
    }

    invokeOnComplete();
  }

//////////////////////////////////////////////////////////////////////////
// Steps
//////////////////////////////////////////////////////////////////////////

  private void openFile() throws Exception
  {
    file.parent().create();
    java.io.File jfile = ((LocalFile)file).toJava();
    zip = new ZipOutputStream(new BufferedOutputStream(new FileOutputStream(jfile)));
  }

  private void closeFile() throws Exception
  {
    zip.close();
  }

  private void writeBackupMeta() throws Exception
  {
    Map props = new Map(Sys.StrType, Sys.StrType);
    props.ordered(true);
    props.set("version",   typeof().pod().version().toString())
         .set("ts",        DateTime.now().toStr())
         .set("file",      file.osPath())
         .set("platform",  Env.cur().platform())
         .set("host",      Env.cur().host())
         .set("indexSize", ""+store.size());

    MemBuf temp = new MemBuf(1024);
    temp.writeProps(props);

    startEntry("backup-meta.props");
    zip.write(temp.buf, 0, temp.size);
    closeEntry();
  }

  private void snapshotIndex() throws Exception
  {
    this.blobs = store.index.snapshot();
  }

  private void initProgressTotal()
  {
    // approx only
    this.progressTotal = store.index.map.size() +
                         auxFiles.sz();
  }

  private void testDelay() throws Exception
  {
    Duration dur = Opts.getDur(opts, "testDelay", null);
    if (dur == null) return;
    // System.out.println("Test delay = " + dur + "...");
    Thread.sleep(dur.millis());
    // System.out.println("Test delay done.");
  }

  private void writePageFiles() throws Exception
  {
    for (int pageSize = Store.minPageSize; pageSize <= Store.maxPageSize; pageSize <<= 1)
      writePageFiles(pageSize);
  }

  private void writePageFiles(int pageSize) throws Exception
  {
    int curPageId = -1;
    PageMgr pages = store.pages;

    // size bounds for this page size
    int min = pageSize == Store.minPageSize ? 0 : (pageSize >> 1) + 1;
    int max = pageSize;

    // iterate blobs looking for pages within this page size
    for (int i=0; i<blobs.length; ++i)
    {
      // check if blob matches page size
      Blob b = blobs[i];
      if (b == null) continue;
      if (b.size < min || b.size > max) continue;

      // allocate and open a new page file if necessary
      if (curPageId == -1)
      {
        curFileId++;
        String dir  = PageMgr.toFileDir(curFileId, pageSize);
        String name = PageMgr.toFileName(curFileId, pageSize);
        startEntry(dir+"/"+name);
      }

      // allocate next page id within this page
      curPageId++;

      // read from source page file
      pages.file(b.fileId).read(b.pageId, buf, 0, b.size);

      // write to zip page file, plus trailing zero bytes
      zip.write(buf, 0, b.size);
      zip.write(zeros, 0, pageSize - b.size);

      // update blob snapshot copy index pointers
      b.fileId = curFileId;
      b.pageId = curPageId;

      // update progress percentage
      advanceProgress("rec");

      // check if we need to close out this page file
      if (curPageId >= Store.pagesPerFile-1)
      {
        closeEntry();
        curPageId = -1;
      }
    }

    // close current entry if we have one open
    if (curPageId != -1) closeEntry();
  }

  private void writeIndex() throws Exception
  {
    int entrySize = Store.indexEntrySize;
    byte[] temp = new byte[entrySize];

    startEntry(Index.fileName);

    // header entry
    zip.write(store.meta.write(), 0, entrySize);

    // write entry for each blob or zero entry for deleted entries
    for (int i=0; i<blobs.length; ++i)
    {
      Blob b = blobs[i];
      if (b == null)
        zip.write(zeros, 0, entrySize);
      else
        zip.write(b.indexEncode(temp), 0, entrySize);
    }

    closeEntry();
  }

//////////////////////////////////////////////////////////////////////////
// Aux/Bin Files
//////////////////////////////////////////////////////////////////////////

  private void findAuxFiles() throws Exception
  {
    List acc = List.makeObj(16);
    try
    {
      // files in root directory
      List files = store.dir.listFiles();
      for (int i=0; i<files.sz(); ++i)
      {
        File f = (File)files.get(i);
        if (f.name().startsWith("folio")) continue;
        if (f.name().startsWith("backup")) continue;
        if (f.name().startsWith(".")) continue;
        if (f.name().equals("db.lock")) continue;
        acc.add(f);
      }
    }
    catch (Exception e) { e.printStackTrace(); }
    this.auxFiles = acc;
  }

  private void writeAuxFiles() throws Exception
  {
    for (int i=0; i<auxFiles.sz(); ++i)
    {
      File f = (File)auxFiles.get(i);
      writeFile(f, f.name());
    }
  }

  private void writeFile(File f, String path) throws Exception
  {
    // update progress percentage
    advanceProgress(path);

    try
    {
      // write file into zip
      startEntry(path);
      f.in().pipe(SysOutStream.make(zip, new Long(4096L)));
      closeEntry();
    }
    catch (Exception e)
    {
      System.out.println("ERROR: Cannot backup file: " + f);
      e.printStackTrace();
    }
  }

  private void invokeOnComplete()
  {
    try
    {
      if (err != null)
        future.completeErr(err);
      else
        future.complete(opts.get("futureResult", toStr()));

      if (onComplete != null)
       onComplete.call(this);
    }
    catch (Exception e)
    {
      e.printStackTrace();
    }
  }

//////////////////////////////////////////////////////////////////////////
// Entries
//////////////////////////////////////////////////////////////////////////

  private void startEntry(String name) throws Exception
  {
    zip.putNextEntry(new ZipEntry(pathPrefix+name));
  }

  private void closeEntry() throws Exception
  {
    zip.closeEntry();
  }

  private synchronized void advanceProgress(String debug)
  {
    progressWritten++;
    int p = 100 * progressWritten / progressTotal;

    if (p < 0) p = 0;
    if (p > 99) p = 99;
    this.progress = p;
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  public String toStr()
  {
    return "" + progress + "% => " + file.name();
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  final Store store;         // ctor
  final File file;           // ctor
  final byte[] buf;          // ctor
  final byte[] zeros;        // ctor
  final String pathPrefix;   // ctor
  final Map opts;            // ctor
  final DateTime startTime;  // ctor
  final Future future;       // ctor
  long progress;             // doRun
  boolean isComplete;        // doRun
  DateTime endTime;          // doRun
  Err err;                   // doRun
  List auxFiles;             // findAuxFiles
  ZipOutputStream zip;       // openFile
  Blob[] blobs;              // snapshotIndex
  int curFileId = -1;        // writePageFiles
  int progressTotal;         // snapshotIndex (approx only for progress)
  int progressWritten;       // writePageFiles (num blob pages written)
  Func onComplete;           // callback
}