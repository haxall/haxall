//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Feb 2016  Brian Frank  Creation
//

using concurrent
using util

**
** StoreTest
**
class StoreTest : Test
{
  Store? s
  Int ver

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    dir := tempDir
    s = Store.open(dir)

    lockPath := Env.cur.tempDir + `test/db.lock`
    verifyErrMsg(CannotAcquireLockFileErr#, lockPath.osPath) { Store.open(dir) }

    // verify meta
    verifyStoreMeta(s)

    verifyEq(s.dir, dir)
    verifyEach([,])

    // create a
    am := Buf().print("a meta")
    ad := Buf().print("a val")
    a := s.create(am, ad);
    aver := ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyEach([a])
    verifyEq(a.stash, null)
    a.stash = "a stash"
    verifyErr(NotImmutableErr#) { a.stash = this }
    verifyEq(a.stash, "a stash")

    // create b
    bm := Buf().print("b meta")
    bd := Buf.random(128)
    bver := ++ver
    b := s.create(bm, bd);
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyEach([a, b])

    // create c
    cm := Buf().print("c meta")
    cd := Buf().print("c 3456789_123456")
    c := s.create(cm, cd)
    cver := ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.1", cver, cm, cd)
    verifyEach([a, b, c])

    // close and reopen
    s.close
    s = Store.open(dir)
    verifyEq(s.size, 3)
    verifyEq(s.ver, ver)
    a = s.blob(a.handle)
    b = s.blob(b.handle)
    c = s.blob(c.handle)
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.1", cver, cm, cd)
    verifyEach([a, b, c])
    verifyEq(a.stash, null)
    a.stash = "a stash"
    verifyEq(a.stash, "a stash")

    // create d
    dm := Buf().print("d meta")
    dd := Buf().print("d rocks!")
    d := s.create(dm, dd);
    dver := ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.1", cver, cm, cd)
    verifyBlob(d, 3, "0.2", dver, dm, dd)
    verifyEach([a, b, c, d])

    // update c
    cd = Buf().print("c changed!")
    c.write(null, cd);
    cver = ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.3", cver, cm, cd)
    verifyBlob(d, 3, "0.2", dver, dm, dd)
    verifyEach([a, b, c, d])

    // create e (reuse's c old data page)
    em := Buf().print("e meta")
    ed := Buf().print("e is it!")
    e := s.create(em, ed);
    ever := ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.3", cver, cm, cd)
    verifyBlob(d, 3, "0.2", dver, dm, dd)
    verifyBlob(e, 4, "0.1", ever, em, ed)
    verifyEach([a, b, c, d, e])

    // delete d
    d.stash = "d stash"
    d.delete
    dver = ++ver
    verifyEq(s.size, 4)
    verifyEq(s.ver, dver)
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.3", cver, cm, cd)
    verifyBlob(e, 4, "0.1", ever, em, ed)
    verifyDeleted(d, 3, dver)
    verifyEach([a, b, c, e], [d])

    // close re-open
    s.close
    s = Store.open(dir)
    a = s.blob(a.handle)
    b = s.blob(b.handle)
    c = s.blob(c.handle)
    d = s.deletedBlob(d.handle)
    e = s.blob(e.handle)
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.3", cver, cm, cd)
    verifyBlob(e, 4, "0.1", ever, em, ed)
    verifyDeleted(d, 3, dver)
    verifyEach([a, b, c, e], [d])

    // add f, reuses d index and data page
    fm := Buf().print("e meta")
    fd := Buf().print("f is it!")
    f := s.create(fm, fd);
    fver := ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.3", cver, cm, cd)
    verifyBlob(e, 4, "0.1", ever, em, ed)
    verifyBlob(f, 3, "0.2", fver, fm, fd)
    verifyEach([a, b, c, e, f])

    // update b meta / f meta+data
    bm = Buf().print("b new meta")
    fm = Buf().print("f new stuff")
    fd = Buf.random(64)
    b.write(bm, null); bver = ++ver
    f.write(fm, fd); fver = ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.3", cver, cm, cd)
    verifyBlob(e, 4, "0.1", ever, em, ed)
    verifyBlob(f, 3, "2.0", fver, fm, fd)
    verifyEach([a, b, c, e, f])

    // verify bad inputs
    ok := Buf.random(3)
    bigMeta := Buf.random(33)
    bigData :=  Buf.random(0x100000 + 1)
    verifyErr(StoreErr#) { s.create(bigMeta, ok) }
    verifyErr(StoreErr#) { s.create(ok, bigData) }
    verifyErr(StoreErr#) { b.write(bigMeta, null) }
    verifyErr(StoreErr#) { b.write(null, bigData) }
    verifyErr(StoreErr#) { b.write(bigMeta, bigData) }

    // add g
    gm := Buf.random(32)
    gd := bigData; gd.size = gd.size - 1
    g := s.create(gm, gd);
    gver := ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.3", cver, cm, cd)
    verifyBlob(e, 4, "0.1", ever, em, ed)
    verifyBlob(f, 3, "2.0", fver, fm, fd)
    verifyBlob(g, 5, "3.0", gver, gm, gd)
    verifyEach([a, b, c, e, f, g])

    // create empty meta/data
    empty := Buf()
    h := s.create(empty, empty); hver := ++ver
    i := s.create(empty.toImmutable, empty); iver := ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.3", cver, cm, cd)
    verifyBlob(e, 4, "0.1", ever, em, ed)
    verifyBlob(f, 3, "2.0", fver, fm, fd)
    verifyBlob(g, 5, "3.0", gver, gm, gd)
    verifyBlob(h, 6, "0.2", hver, empty, empty)
    verifyBlob(i, 7, "0.4", iver, empty, empty)
    verifyEach([a, b, c, e, f, g, h, i])

    // set readonly
    verifyEq(s.ro, false)
    s.ro = true
    verifyEq(s.ro, true)
    verifyErrMsg(StoreErr#, "Store is readonly") { s.create(Buf(), Buf()) }
    verifyErrMsg(StoreErr#, "Store is readonly") { a.write("bad".toBuf, "in ro!".toBuf) }
    verifyErrMsg(StoreErr#, "Store is readonly") { b.append("bad".toBuf, "in ro!".toBuf) }
    verifyErrMsg(StoreErr#, "Store is readonly") { f.delete }
    verifyBlob(a, 0, "0.0", aver, am, ad)

    // close and reopen
    s.close
    s = Store.open(dir)
    verifyStoreMeta(s)
    a = s.blob(a.handle)
    b = s.blob(b.handle)
    c = s.blob(c.handle)
    e = s.blob(e.handle)
    f = s.blob(f.handle)
    g = s.blob(g.handle)
    h = s.blob(h.handle)
    i = s.blob(i.handle)
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyBlob(b, 1, "1.0", bver, bm, bd)
    verifyBlob(c, 2, "0.3", cver, cm, cd)
    verifyBlob(e, 4, "0.1", ever, em, ed)
    verifyBlob(f, 3, "2.0", fver, fm, fd)
    verifyBlob(g, 5, "3.0", gver, gm, gd)
    verifyBlob(h, 6, "0.2", hver, empty, empty)
    verifyBlob(i, 7, "0.4", iver, empty, empty)
    verifyEach([a, b, c, e, f, g, h, i])
    verifyEq(s.blob(d.handle, false), null)
    verifyErr(UnknownBlobErr#) { s.blob(d.handle) }

    s.close
    verifyErrMsg(StoreErr#, "Store is closed") { s.create(Buf(), Buf()) }
    verifyErrMsg(StoreErr#, "Store is closed") { a.read(Buf()) }
    verifyErrMsg(StoreErr#, "Store is closed") { a.write(Buf(), null) }
    verifyErrMsg(StoreErr#, "Store is closed") { a.delete }
  }

  private Void verifyStoreMeta(Store s)
  {
    verifyEq(s.typeof.name, "Store")
    verifyEq(s.meta.typeof.name, "StoreMeta")
    verifyEq(s.meta.blobMetaMax, 32)
    verifyEq(s.meta.blobDataMax, 1048576)
    verifyEq(s.meta.hisPageSize, 10day)
  }

//////////////////////////////////////////////////////////////////////////
// WriteErr
//////////////////////////////////////////////////////////////////////////

  Void testOnWriteErr()
  {
    dir := tempDir
    s = Store.open(dir)
    a := s.create("a".toBuf, "alpha".toBuf)

    s.testDiskFull = true

    verifyOnWriteErr { this.s.create("b".toBuf, "beta".toBuf) }
    verifyOnWriteErr { a.write(null, "alpha 2".toBuf) }

    verifyEq(s.size, 1)
    verifyErr(UnknownBlobErr#) { s.blob(1) }
    verifyBlobStr(s.blob(a.handle), "alpha")

    verifyOnWriteErr { a.append(null, "append!".toBuf) }
    verifyBlobStr(s.blob(a.handle), "alpha")

    s.close

    s = Store.open(dir)
    verifyEq(s.size, 1)
    verifyErr(UnknownBlobErr#) { s.blob(1) }
    verifyBlobStr(s.blob(a.handle), "alpha")

    s.close
  }

  Void verifyOnWriteErr(|This| f)
  {
    Err? err := null
    cb := |Err e| { err = e }
    s.onWriteErr = cb
    verifySame(s.onWriteErr, cb)
    verifyErrMsg(IOErr#, "java.io.IOException: Disk full test") { f(this) }
    verifyEq(err?.typeof, IOErr#)
  }

  Void verifyBlobStr(Blob b, Str expected)
  {
    buf := Buf()
    b.read(buf)
    verifyEq(buf.readAllStr, expected)
  }

//////////////////////////////////////////////////////////////////////////
// Append
//////////////////////////////////////////////////////////////////////////

  Void testAppend()
  {
    dir := tempDir
    s = Store.open(dir)

    // create a
    am := Buf().print("a meta")
    ad := Buf().print("a val.")
    a := s.create(am, ad);
    aver := ++ver
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyEach([a])

    // now append some data
    a.append(null, Buf().print("foo bar.")); aver = ++ver
    ad = Buf().print("a val.foo bar.")
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyEach([a])

    // append with invalid meta
    verifyErr(StoreErr#) { a.append(Buf.random(33), Buf.random(2)) }
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyEach([a])

    // append right to 16 byte boundary
    a.append(null, Buf().print("x.")); aver = ++ver
    ad = Buf().print("a val.foo bar.x.")
    verifyBlob(a, 0, "0.0", aver, am, ad)
    verifyEach([a])

    // append one more byte to push us to new 32 byte page
    a.append(null, Buf().print("!")); aver = ++ver
    ad = Buf().print("a val.foo bar.x.!")
    verifyBlob(a, 0, "1.0", aver, am, ad)
    verifyEach([a])

    // append 16 bytes to push to 64 byte page, plus change meta
    am = Buf().print("some new a meta")
    ad = Buf().print("a val.foo bar.x.!abcdefghijklmnop")
    a.append(am, Buf().print("abcdefghijklmnop")); aver = ++ver
    verifyBlob(a, 0, "2.0", aver, am, ad)
    verifyEach([a])

    // add couple more bytes with meta change
    am = Buf().print("meta change 3")
    ad = Buf().print("a val.foo bar.x.!abcdefghijklmnop!")
    a.append(am, "!".toBuf); aver = ++ver
    verifyBlob(a, 0, "2.0", aver, am, ad)
    verifyEach([a])

    // close and re-open
    s.close
    verifyErrMsg(StoreErr#, "Store is closed") { a.append(null, Buf().print("xyz!")) }
    s = Store.open(dir)
    a = s.blob(a.handle)
    verifyBlob(a, 0, "2.0", aver, am, ad)
    verifyEach([a])

    // randomly append data up to 1MB
    pageId := 2
    incr := 10
    maxSize := 0x100000
    while (a.size + incr*2 + 1 < 1048576)
    {
      buf := Buf.random((incr..incr*2).random)

      oldPageSize := bestPageSize(ad.size)
      ad.seek(ad.size).writeBuf(buf)
      newPageSize := bestPageSize(ad.size)
      if (newPageSize != oldPageSize) { pageId++; incr *= 2 }

      a.append(null, buf); aver = ++ver
      verifyBlob(a, 0, "${pageId}.0", aver, am, ad)
    }

    // verify we can't append over 1MB
    buf := Buf.random(maxSize - ad.size + 1)
    verifyErr(StoreErr#) { a.append(null, buf) }

    // close and re-open
    s.close
    verifyErrMsg(StoreErr#, "Store is closed") { a.append(null, Buf().print("xyz!")) }
    s = Store.open(dir)
    a = s.blob(a.handle)
    verifyBlob(a, 0, "${a.fileId}.0", aver, am, ad)
    verifyEach([a])

    // do normal write
    ad = Buf.random(16)
    a.write(null, ad); aver = ++ver
    verifyBlob(a, 0, "${a.fileId}.0", aver, am, ad)
    verifyEach([a])
  }

//////////////////////////////////////////////////////////////////////////
// Write Expected Ver
//////////////////////////////////////////////////////////////////////////

  Void testWriteExpectedVer()
  {
    dir := tempDir
    s = Store.open(dir)

    am := Buf().print("a meta")
    ad := Buf().print("a val")
    a := s.create(am, ad)
    verifyBlob(a, 0, "0.0", 1, am, ad)

    // verify write errors
    verifyErr(ConcurrentWriteErr#) { a.write(null, "bad".toBuf, 2) }
    verifyErr(ConcurrentWriteErr#) { a.write("bad".toBuf, null, 2) }
    verifyErr(ConcurrentWriteErr#) { a.write("bad".toBuf, "bad".toBuf, 2) }

    // no changes yet
    verifyBlob(a, 0, "0.0", 1, am, ad)

    // write meta with correct version
    a.write(null, "new val".toBuf, 1)
    verifyBlob(a, 0, "0.1", 2, am, "new val".toBuf)

    // write data with correct version
    a.write("new meta".toBuf, null, 2)
    verifyBlob(a, 0, "0.1", 3, "new meta".toBuf, "new val".toBuf)

    // write both with correct version
    a.write("new meta 2".toBuf, "new val 2".toBuf, 3)
    verifyBlob(a, 0, "0.0", 4, "new meta 2".toBuf, "new val 2".toBuf)

    // one more time
    verifyErr(ConcurrentWriteErr#) { a.write("bad".toBuf, "bad".toBuf, 3) }
    verifyBlob(a, 0, "0.0", 4, "new meta 2".toBuf, "new val 2".toBuf)

    s.close
  }

//////////////////////////////////////////////////////////////////////////
// Config
//////////////////////////////////////////////////////////////////////////

  Void testConfig()
  {
    verifyErr(Err#) { x := StoreConfig { it.hisPageSize = 1min } }
    verifyErr(Err#) { x := StoreConfig { it.hisPageSize = 101day } }
    verifyErr(Err#) { x := StoreConfig { it.hisPageSize = 2.3hr } }

    // create with 1day
    dir := tempDir
    s := Store.open(dir, StoreConfig { it.hisPageSize = 1day })
    verifyEq(s.meta.hisPageSize, 1day)
    s.close

    // open w/ null config
    s = Store.open(dir)
    verifyEq(s.meta.hisPageSize, 1day)
    s.close

    // open with ignored config
    s = Store.open(dir,  StoreConfig { it.hisPageSize = 10day })
    verifyEq(s.meta.hisPageSize, 1day)
    s.close
  }

//////////////////////////////////////////////////////////////////////////
// Flush
//////////////////////////////////////////////////////////////////////////

  Void testFlush()
  {
    // default is fsync
    dir := tempDir
    s := Store.open(dir)
    verifyEq(s.flushMode, "fsync")

    // bad mode
    verifyErr(ArgErr#) { s.flushMode = "bad" }
    verifyEq(s.flushMode, "fsync")

    // make some changes
    verifyEq(s.unflushedCount, 0)
    a := s.create("a".toBuf, "first rec".toBuf)
    b := s.create("b".toBuf, "second rec".toBuf)
    c := s.create("c".toBuf, "third rec".toBuf)
    verifyEq(s.unflushedCount, 0)

    // nosync
    s.flushMode = "nosync"
    verifyEq(s.flushMode, "nosync")
    d := s.create("d".toBuf, "forth rec".toBuf)
    verifyEq(s.unflushedCount, 2)
    a.write(null, "this is a change".toBuf)
    verifyEq(s.unflushedCount, 2)
    b.write(null, Buf.random(64))
    verifyEq(s.unflushedCount, 3)

    // flush
    s.flush
    verifyEq(s.unflushedCount, 0)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verifyEach(Blob[] active, Blob[] deleted := Blob[,])
  {
    verifyEq(s.ver, ver)
    verifyEq(s.size, active.size)
    verifyEq(s.deletedSize, deleted.size)

    acc := Int:Blob[:]
    s.each |b| { acc.add(b.handle, b) }
    verifyEq(acc.size, active.size)
    active.each |b| { verifySame(acc[b.handle], b) }

    acc.clear
    s.deletedEach |b| { acc.add(b.handle, b) }
    verifyEq(acc.size, deleted.size)
    deleted.each |b| { verifySame(acc[b.handle], b) }
  }

  Void verifyBlob(Blob b, Int handleIndex, Str loc, Int ver, Buf meta, Buf data)
  {
    verifyEq(b.isActive, true)
    verifyEq(b.isDeleted, false)
    verifySame(s.blob(b.handle), b)
    verifyEq(s.deletedBlob(b.handle, false), null)
    verifyErr(UnknownBlobErr#) { s.deletedBlob(b.handle) }

    // echo(":: $b  $b.meta.size | ${b.fileId}.$b.pageId | $b.size")
    verifyEq(b.handle.and(0x7fff_ffff), handleIndex)
    verifyEq(b.size, data.size)
    verifyEq(b.ver, ver)
    verifyEq("${b.fileId}.${b.pageId}", loc)

    verifyEq(b.meta.size, meta.size)
    meta.size.times |i| { verifyEq(b.meta[i], meta[i]) }

    buf := Buf()
    b.read(buf)
    verifyEq(buf.size, data.size)
    buf.size.times |i|
    {
      // echo("  data: $i " + buf[i].toChar.toCode + " ?= " + data[i].toChar.toCode)
      verifyEq(buf[i], data[i])
    }
  }

  Void verifyDeleted(Blob b, Int handleIndex, Int ver)
  {
    verifyEq(b.handle.and(0x7fff_ffff), handleIndex)
    verifyEq(b.ver, ver)
    verifyErrMsg(StoreErr#, "Blob is deleted") { b.read(Buf()) }
    verifyErrMsg(StoreErr#, "Blob is deleted") { b.write(null, Buf.random(4)) }
    verifyErrMsg(StoreErr#, "Blob is deleted") { b.delete }
    verifyEq(b.size, -1)
    verifySame(s.deletedBlob(b.handle), b)
    verifyEq(s.blob(b.handle, false), null)
    verifyErr(UnknownBlobErr#) { s.blob(b.handle) }
  }

  static Int bestPageSize(Int size)
  {
    x := 2
    while (size > x) x = x.shiftl(1)
    return x
  }
}

