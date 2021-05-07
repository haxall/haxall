//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Nov 2015  Brian Frank  Creation
//

using concurrent
using haystack
using folio

**
** DisMgrTest
**
class DisMgrTest : WhiteboxTest
{

  Void test()
  {
    open
    disMgr := folio.disMgr

    // create b *before* a
    b := addRec(["disMacro":"\$aRef \$navName", "navName":"B", "aRef":Ref("foo")])
    verifyDis(b, "foo B")

    // create a
    a := addRec(["dis":"A"])
    verifyDis(a, "A")

    // update a
    a2 := commit(a, ["dis":"A-2"])
    verifySame(a.id, a2.id)
    verifyDis(a2, "A-2")
    verifyEq(a.id.dis, "A-2")

    // point b.aRef, refs
    b = commit(b, ["aRef":Ref(a.id.id), "refs":[Ref(a.id.id), "foo", Ref(b.id.id)]])
    disMgr.sync
    verifySameRef(b->aRef, a.id, "A-2")
    verifySameRef(b->refs->get(0), a.id, "A-2")
    verifySameRef(b->refs->get(2), b.id, "A-2 B")
    verifyDis(b, "A-2 B")

    // update b's navName
    b = commit(b, ["navName":"B-2"])
    disMgr.sync
    verifyDis(b, "A-2 B-2")
    verifySameRef(b->refs->get(2), b.id, "A-2 B-2")

    // update a, and verify b
    a = commit(a2, ["dis":"A-3"])
    disMgr.sync
    verifyDis(a, "A-3")
    verifyDis(b, "A-3 B-2")

    // create c
    c := addRec(["disMacro": "a:\$aRef | b:\$bRef | x:\$xRef", "aRef":a.id, "bRef":b.id, "xRef":Ref("X")])
    verifySame(c->aRef, a.id)
    verifySame(c->bRef, b.id)
    verifyDis(c, "a:A-3 | b:A-3 B-2 | x:X")

    // verify updateAll coalesces
    n1 := folio.disMgr.updateAllCount.val
    folio.disMgr.send(Msg(MsgId.testSleep, 100ms))
    100.times { disMgr.updateAll }
    disMgr.sync
    n2 := disMgr.updateAllCount.val
    verifyEq(n1, n2 - 1)

    // close and reopen
    reopen
    disMgr = folio.disMgr
    a = readById(a.id)
    b = readById(b.id)
    c = readById(c.id)
    verifySameRef(b->aRef, a.id, "A-3")
    verifySameRef(c->aRef, a.id, "A-3")
    verifySameRef(c->bRef, b.id, "A-3 B-2")
    verifySameRef(b->refs->get(0), a.id, "A-3")
    verifySameRef(b->refs->get(2), b.id, "A-3 B-2")
    verifyDis(a, "A-3")
    verifyDis(b, "A-3 B-2")
    verifyDis(c, "a:A-3 | b:A-3 B-2 | x:X")


    // make batch change to a and b
    20.times |i|
    {
      folio.commitAll([
        Diff(a, ["dis":"A-$i"]),
        Diff(b, ["navName":"B-$i"])
       ])
      disMgr.sync
      a = readById(a.id)
      b = readById(b.id)
      c = readById(c.id)
      verifyEq(a.id.dis, "A-$i")
      verifyEq(b.id.dis, "A-$i B-$i")
      verifyEq(c.id.dis, "a:A-$i | b:A-$i B-$i | x:X")
    }

    // nuke a
    folio.commit(Diff(a, null, Diff.remove))
    disMgr.sync
    b = readById(b.id)
    c = readById(c.id)
    verifyEq(a.id.disVal, null)
    verifySame(b->aRef, a.id)
    verifyEq(b.id.dis, "$a.id.id B-19")
    verifyEq(c.id.dis, "a:$a.id.id | b:$a.id.id B-19 | x:X")

    // cleanup
    close
  }

  Void verifySameRef(Ref a, Ref b, Str dis)
  {
    verifySame(a, b)
    verifyEq(a.dis, dis)
    verifyEq(b.dis, dis)
  }

  Void verifyDis(Dict r, Str dis)
  {
    verifyEq(r.dis, dis)
    verifyEq(r.id.dis, dis)
    verifyEq(r.id.disVal, dis)
    verifyEq(folio.readById(r.id).id.dis, dis)
  }

}



