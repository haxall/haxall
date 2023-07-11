//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jun 2016  Brian Frank  Creation
//

using concurrent

**
** BackupTest
**
class BackupTest : Test
{
  Store? src
  Int backupCount
  Str:Str files := [:]

  Void testBasics()
  {
    srcDir := tempDir+`src/`
    config := StoreConfig { it.hisPageSize = 2day }
    src = Store.open(srcDir, config)
    verifyEq(src.meta.hisPageSize, 2day)

    // empty
    verifyBackup

    // one blobs
    a := src.create(Buf().print("a meta"), Buf().print("a val"))
    verifyBackup

    // two blobs
    b := src.create(Buf().print("b meta"), Buf().print("b val"))
    verifyBackup

    // couple different page sizes, updates
    c := src.create(Buf.random(32), Buf.random(16))
    d := src.create(Buf.random(32), Buf.random(17))
    3.times { b.write(null, Buf.random(33)) }
    verifyBackup

    // deletes
    a.delete
    c.delete
    verifyBackup

    // add some files
    addFile("passwords.props", "password db")
    addFile("alpha.txt", "Alpha!")
    addFile("beta.txt", "Beta!")
    addFile("backup-info.txt", "nope!")
    addFile("folio-info.txt", "nope!")
    verifyBackup

    // add bunch of recs in 16, 32, 64, 128 sizes; then make bunch of updates
    x := Blob[,]
    100.times |i| { x.add(src.create(rand(0..32), rand(0..66))) }
    100.times |i| { x.random.write(null, rand(32..129)) }
    verifyBackup

    // make safe copy of the database
    tempDir.plus(`dst/`).moveTo(tempDir.plus(`copy/`))

    // now make a bunch of changes while doing a backup
    toFree := BackupAddr[,]
    zipFile := doBackup |->|
    {
      100.times |i| { src.create(rand(0..32), rand(0..66))  }
      100.times |i|
      {
        blob := x.random
        toFree.add(BackupAddr(blob))
        blob.write(rand(0..32), rand(0..200))
        verifyUsed(src, toFree.last, true)
      }
      100.times |i| { x.random.append(null, rand(1..10)) }
      10.times |i| { try { x.random.delete } catch {} }
    }
    toFree.each |f| { verifyUsed(src, f, false) }
    origSrc := Store.open(tempDir.plus(`copy/`))
     dstDir := unzipBackup(zipFile)
    dst := Store.open(dstDir)
    verifyStoreEq(origSrc, dst)
    origSrc.close
    dst.close

    // make few more changes to verify GC queue nulled out
    blob := x.random
    while (blob.fileId < 0) blob = x.random
    addr := BackupAddr(blob)
    verifyUsed(src, addr, true)
    blob.write(null, "hi there".toBuf)
    verifyUsed(src, addr, false)

    // fill up 16 byte page file
    /* this tests takes 9sec+
    t1 := Duration.now
    echo("Writing 70K random pages... ")
    meta := Buf.random((0..32).random)
    x16s := Blob[,]
    70_000.times |i|
    {
      dataSize := (1..16).random
      x16s.add(src.create(meta, Buf.random(dataSize)))
    }
    t2 := Duration.now
    echo("Write random " + (t2-t1).toLocale)
    verifyBackup
    */

    src.close
  }

  Void addFile(Str name, Str content)
  {
    file := src.dir + `${name}`
    file.out.print(content).close
    files[name] = content
  }

  Void verifyBackup()
  {
    zipFile := doBackup(null)

    dstDir := unzipBackup(zipFile)

    dst := Store.open(dstDir)
    verifyStoreEq(src, dst)
    dst.close

    // verify files in dir bundled into backup
    files.each |expected, name|
    {
      file := dstDir + `${name}`
      if (expected == "nope!")
        verifyEq(file.exists, false)
      else
        verifyEq(file.readAllStr, expected)
    }
  }

  File doBackup(|->|? doWhile)
  {
    // opts
    opts := Str:Obj["pathPrefix":`dst/`, "futureResult":"_done_"]
    if (doWhile != null) opts["testDelay"] = 100ms

    // kick off backup
    verifyEq(src.gcFreezeCount, 0)
    verifyEq(src.backup, null)
    file := tempDir + `backup-${backupCount++}.zip`
    counterVal := counter.val
    b := src.backup(file, opts)
    verifyEq(b.future.status, FutureStatus.pending)
    b.onComplete { counter.getAndIncrement }
    verifySame(src.backup, b)
    verifySame(b.store, src)
    verifySame(b.file, file)
    verifyErrMsg(StoreErr#, "A backup operation is already in progress") { src.backup(this.tempDir+`foobar.zip`) }

    // run work file backup thread is running
    if (doWhile != null)
    {
      Actor.sleep(10ms)
      doWhile()
    }

    // wait until done
    //echo("### Verify Backup")
    while (!b.isComplete)
    {
      verifyEq(src.gcFreezeCount, 1)
      //echo("  Progress: $b.progress")
      Actor.sleep(20ms)
    }
    //echo("Backup complete")

    verifyEq(src.gcFreezeCount, 0)
    verifyEq(b.progress, 100)
    verifyEq(counter.val, counterVal+1)
    verifyEq(b.future.status, FutureStatus.ok)
    verifyEq(b.future.get, "_done_")
    if (b.err != null) throw b.err

    return b.file
  }

  static const AtomicInt counter := AtomicInt()

  File unzipBackup(File zipFile)
  {
    // unzip it
    zip := Zip.open(zipFile)
    dstDir := tempDir + `dst/`
    dstDir.delete
    zip.contents.each |f|
    {
      f.copyTo(tempDir + f.pathStr[1..-1].toUri)
    }

    // verify backup-meta
    meta := dstDir.plus(`backup-meta.props`).readProps
    verifyEq(meta["version"], typeof.pod.version.toStr)
    verifyEq(DateTime.fromStr(meta["ts"]).date, Date.today)

    return dstDir
  }

  Void verifyStoreEq(Store a, Store b)
  {
    verifyEq(a.size, b.size)
    verifyEq(a.ver, b.ver)
    verifyStoreMetaEq(a.meta, b.meta)
    b.each |bb| { verifyBlobEq(a.blob(bb.handle), bb) }
    b.deletedEach |bb| { verifyBlobEq(a.deletedBlob(bb.handle), bb) }
  }

  Void verifyStoreMetaEq(StoreMeta a, StoreMeta b)
  {
    verifyEq(a.blobMetaMax,  b.blobMetaMax)
    verifyEq(a.blobDataMax,  b.blobDataMax)
    verifyEq(a.hisPageSize,  b.hisPageSize)
  }

  Void verifyBlobEq(Blob a, Blob b)
  {
    verifyEq(a.isActive, b.isActive)
    verifyEq(a.isDeleted, b.isDeleted)
    verifyEq(a.ver, b.ver)
    verifyEq(a.size, b.size)
    if (a.isDeleted)
    {
      verifyEq(a.handle.and(0xffff_ffff), b.handle.and(0xffff_ffff))
      verifyErr(StoreErr#) { a.read(Buf()) }
      verifyErr(StoreErr#) { b.read(Buf()) }
    }
    else
    {
      verifyBlobMetaEq(a.meta, b.meta)
      verifyEq(a.handle, b.handle)
      verifyBufEq(a.read(Buf()), b.read(Buf()))
    }
  }

  Void verifyBlobMetaEq(BlobMeta a, BlobMeta b)
  {
    verifyEq(b.size, b.size)
    a.size.times |i| { verifyEq(a[i], b[i]) }
  }

  Void verifyBufEq(Buf a, Buf b)
  {
    verifyEq(b.size, b.size)
    a.size.times |i| { verifyEq(a[i], b[i]) }
  }

  internal Void verifyUsed(Store store, BackupAddr addr, Bool isUsed)
  {
    verifyEq(store.isUsed(addr.fileId, addr.pageId), isUsed)
  }

  static Buf rand(Range r) { Buf.random(r.random) }

}

internal class BackupAddr
{
  new make(Blob b) { fileId = b.fileId; pageId = b.pageId }
  const Int fileId
  const Int pageId
  override Str toStr() { "$fileId:$pageId" }
}

