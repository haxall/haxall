//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2016  Brian Frank  Creation
//

using concurrent
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

  Void test() { fullImpls }
  Void doTest()
  {
    f := open

    // add a, b, c, d
    a := addRec(["id":Ref("A-ID"), "dis":"A-0"])
    b := addRec(["id":Ref("B-ID"), "disMacro":"\$aRef \$navName", "aRef":a.id, "navName":"B-0"])
    c := addRec(["id":Ref("C-ID"), "disMacro":"\$bRef \$navName", "bRef":b.id, "navName":"C-0"])
    d := addRec(["id":Ref("D-ID"), "disMacro":"\$cRef \$navName", "cRef":c.id, "navName":"D-0"])
    verifyDis(a, "A-0")
    verifyDis(b, "A-0 B-0")
    verifyDis(c, "A-0 B-0 C-0")
    verifyDis(d, "A-0 B-0 C-0 D-0")

    // update a and verify it ripples thru
    a = commit(a, ["dis":"A-1"])
    syncDis
    verifyDis(a, "A-1")
    verifyDis(b, "A-1 B-0")
    verifyDis(c, "A-1 B-0 C-0")
    verifyDis(d, "A-1 B-0 C-0 D-0")

    // update b and verify it ripples
    b = commit(b, ["navName":"B-1"])
    syncDis
    verifyDis(a, "A-1")
    verifyDis(b, "A-1 B-1")
    verifyDis(c, "A-1 B-1 C-0")
    verifyDis(d, "A-1 B-1 C-0 D-0")

    // update c and verify it ripples
    c = commit(c, ["navName":"C-1"])
    syncDis
    verifyDis(a, "A-1")
    verifyDis(b, "A-1 B-1")
    verifyDis(c, "A-1 B-1 C-1")
    verifyDis(d, "A-1 B-1 C-1 D-0")

    // update d
    d = commit(d, ["navName":"D-1"])
    syncDis
    verifyDis(a, "A-1")
    verifyDis(b, "A-1 B-1")
    verifyDis(c, "A-1 B-1 C-1")
    verifyDis(d, "A-1 B-1 C-1 D-1")

    // change bRef on c
    bx := addRec(["id":Ref("BX-ID"), "dis":"BX-0"])
    c = commit(c, ["bRef":bx.id])
    syncDis
    verifyDis(a,  "A-1")
    verifyDis(b,  "A-1 B-1")
    verifyDis(bx, "BX-0")
    verifyDis(c,  "BX-0 C-1")
    verifyDis(d,  "BX-0 C-1 D-1")

    // update bX to point to a
    bx = commit(bx, ["dis":Remove.val, "disMacro":"\$aRef \$navName", "aRef":a.id, "navName":"BX-1"])
    syncDis
    verifyDis(a,  "A-1")
    verifyDis(b,  "A-1 B-1")
    verifyDis(bx, "A-1 BX-1")
    verifyDis(c,  "A-1 BX-1 C-1")
    verifyDis(d,  "A-1 BX-1 C-1 D-1")

    // update bx to point to itself
    bx = commit(bx, ["aRef":bx.id, "navName":"NN"])
    syncDis
    verifyDis(a,  "A-1")
    verifyDis(b,  "A-1 B-1")
    verifyDis(c,  "BX-ID NN C-1")
    verifyDis(d,  "BX-ID NN C-1 D-1")
    verifyEq(folio.readById(bx.id).id.dis, "BX-ID NN")

    // batch change: update a, b, and c.bRef
    folio.commitAll([
      Diff(a, ["dis":"A-2"], Diff.force),
      Diff(b, ["navName":"B-2"], Diff.force),
      Diff(c, ["bRef":b.id, "navName":"C-2"], Diff.force)])
    syncDis
    verifyDis(a,  "A-2")
    verifyDis(b,  "A-2 B-2")
    verifyDis(c,  "A-2 B-2 C-2")
    verifyDis(d,  "A-2 B-2 C-2 D-1")
    verifyEq(folio.readById(bx.id).id.dis, "BX-ID NN")

    // reopen and test again
    reopen
    verifyDis(a,  "A-2")
    verifyDis(b,  "A-2 B-2")
    verifyDis(c,  "A-2 B-2 C-2")
    verifyDis(d,  "A-2 B-2 C-2 D-1")
    verifyEq(folio.readById(bx.id).id.dis, "BX-ID NN")

    // delete b
    removeRec(b)
    syncDis
    verifyDis(a,  "A-2")
    verifyDis(c,  "B-ID C-2")
    verifyDis(d,  "B-ID C-2 D-1")
  }

  Void syncDis()
  {
    Actor.sleep(10ms)
  }

  Void verifyDis(Dict r, Str dis)
  {
    r = folio.readById(r.id)
    verifyEq(r.dis, dis)
    verifyEq(r.id.dis, dis)
  }

}

