//
// Copyright (c) 2017, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Oct 2017  Brian Frank  Creation
//

using concurrent
using haystack
using folio

**
** MiscTest
**
class MiscTest : WhiteboxTest
{
  Int counter

  Void testIntern()
  {
    open

    a := addRec(["dis":"x", "date": Date.today, "ref": Ref("xxx"), "sym": Symbol("bar")])
    b := addRec(["dis":"x", "date": Date.today, "ref": Ref("xxx"), "sym": Symbol("bar")])

    reopen

    a = folio.readById(a.id)
    b = folio.readById(b.id)

    verifySame(a->dis,  b->dis)
    verifySame(a->date, b->date)
    verifySame(a->ref,  b->ref)
    verifySame(a->sym,  b->sym)

    close
  }

  Void testSync()
  {
    open

    tz := TimeZone.cur
    ts := DateTime.now.floor(1min)
    pt := addRec(["dis":"Point!", "point":m, "his":m, "kind":"Number", "tz":tz.name, "ts":ts])

    verifySync("index",       [folio.index])
    verifySync("store",       [folio.store])
    verifySync("index,store", [folio.index, folio.store])
    verifySync("store",       [folio.store])
    verifySync("all!",        [folio.index, folio.store])

    close
  }

  private Void verifySync(Str test, HxFolioMgr[] mgrs)
  {
    // setup
    counter++
    pt := folio.read("point")
    t1 := Duration.now
    index := folio.dir+`folio.index`
    crc1 := index.readAllBuf.crc("CRC-32")
    spark := Etc.makeDict(["targetRef":pt.id, "ruleRef":Ref("foo"), "date":Date.today, "counter":n(counter)])

    // add delay to given managers
    delay := 200ms
    mgrs.each |mgr| { mgr.send(Msg(MsgId.testSleep, delay)) }

    // add Rec
    f1 := folio.commitAsync(Diff.makeAdd(["test":test]))
    verifyEq(f1.state, FutureState.pending)

    // sync with timeout
    verifyErr(TimeoutErr#) { folio.sync(100ms) }

    // finish sync
    folio.sync(1sec)

    // read back changes
    t2 := Duration.now
    crc2 := index.readAllBuf.crc("CRC-32")
    diff := t2 - t1
    verifyEq(f1.state, FutureState.ok)
    verify(diff > delay && diff < delay+100ms)
    verifyNotEq(crc1, crc2)

    // check add rec
    dict := f1.dict
    verifyEq(dict->test, test)
  }

}