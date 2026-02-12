//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2016  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio

**
** DisTest
**
class DisTest : AbstractFolioTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void test() { runImpls }
  Void doTest()
  {
    f := open

    // add a, b, c, d
    a := addRec(["id":Ref("A-ID"), "dis":"A-0"])
    b := addRec(["id":Ref("B-ID"), "disMacro":"\$aRef \$navName", "aRef":a.id, "navName":"B-0"])
    c := addRec(["id":Ref("C-ID"), "disMacro":"\$bRef \$navName", "bRef":b.id, "navName":"C-0"])
    d := addRec(["id":Ref("D-ID"), "disMacro":"\$cRef \$navName", "cRef":c.id, "navName":"D-0"])
    verifyDictDis(a, "A-0")
    verifyDictDis(b, "A-0 B-0")
    verifyDictDis(c, "A-0 B-0 C-0")
    verifyDictDis(d, "A-0 B-0 C-0 D-0")

    // update a and verify it ripples thru
    a = commit(a, ["dis":"A-1"])
    syncDis
    verifyEq(a.dis, "A-1")
    verifyEq(a.id.dis, "A-1")
    verifyDictDis(a, "A-1")
    verifyDictDis(b, "A-1 B-0")
    verifyDictDis(c, "A-1 B-0 C-0")
    verifyDictDis(d, "A-1 B-0 C-0 D-0")

    // update b and verify it ripples
    b = commit(b, ["navName":"B-1"])
    syncDis
    verifyDictDis(a, "A-1")
    verifyDictDis(b, "A-1 B-1")
    verifyDictDis(c, "A-1 B-1 C-0")
    verifyDictDis(d, "A-1 B-1 C-0 D-0")

    // update c and verify it ripples
    c = commit(c, ["navName":"C-1"])
    syncDis
    verifyDictDis(a, "A-1")
    verifyDictDis(b, "A-1 B-1")
    verifyDictDis(c, "A-1 B-1 C-1")
    verifyDictDis(d, "A-1 B-1 C-1 D-0")

    // update d
    d = commit(d, ["navName":"D-1"])
    syncDis
    verifyDictDis(a, "A-1")
    verifyDictDis(b, "A-1 B-1")
    verifyDictDis(c, "A-1 B-1 C-1")
    verifyDictDis(d, "A-1 B-1 C-1 D-1")

    // change bRef on c
    bx := addRec(["id":Ref("BX-ID"), "dis":"BX-0"])
    c = commit(c, ["bRef":bx.id])
    syncDis
    verifyDictDis(a,  "A-1")
    verifyDictDis(b,  "A-1 B-1")
    verifyDictDis(bx, "BX-0")
    verifyDictDis(c,  "BX-0 C-1")
    verifyDictDis(d,  "BX-0 C-1 D-1")

    // update bX to point to a
    bx = commit(bx, ["dis":None.val, "disMacro":"\$aRef \$navName", "aRef":a.id, "navName":"BX-1"])
    syncDis
    verifyDictDis(a,  "A-1")
    verifyDictDis(b,  "A-1 B-1")
    verifyDictDis(bx, "A-1 BX-1")
    verifyDictDis(c,  "A-1 BX-1 C-1")
    verifyDictDis(d,  "A-1 BX-1 C-1 D-1")

    // update bx to point to itself
    bx = commit(bx, ["aRef":bx.id, "navName":"NN"])
    syncDis
    verifyDictDis(a,  "A-1")
    verifyDictDis(b,  "A-1 B-1")
    verifyDictDis(c,  "BX-ID NN C-1")
    verifyDictDis(d,  "BX-ID NN C-1 D-1")
    verifyIdDis(folio.readById(bx.id).id, "BX-ID NN")

    // batch change: update a, b, and c.bRef
    folio.commitAll([
      Diff(a, ["dis":"A-2"], Diff.force),
      Diff(b, ["navName":"B-2"], Diff.force),
      Diff(c, ["bRef":b.id, "navName":"C-2"], Diff.force)])
    syncDis
    verifyDictDis(a,  "A-2")
    verifyDictDis(b,  "A-2 B-2")
    verifyDictDis(c,  "A-2 B-2 C-2")
    verifyDictDis(d,  "A-2 B-2 C-2 D-1")
    verifyIdDis(folio.readById(bx.id).id, "BX-ID NN")

    // reopen and test again
    reopen
    verifyDictDis(a,  "A-2")
    verifyDictDis(b,  "A-2 B-2")
    verifyDictDis(c,  "A-2 B-2 C-2")
    verifyDictDis(d,  "A-2 B-2 C-2 D-1")
    verifyIdDis(folio.readById(bx.id).id, "BX-ID NN")

    // delete b
    removeRec(b)
    syncDis
    verifyDictDis(a, "A-2")
    verifyDictDis(c, "B-ID C-2")
    verifyDictDis(d, "B-ID C-2 D-1")
  }

  Void syncDis()
  {
    Actor.sleep(10ms)
    folio.sync(null, "dis")
  }



}

