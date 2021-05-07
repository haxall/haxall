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
** StoreMgrTest
**
class StoreMgrTest : WhiteboxTest
{

  Void testWriteNum()
  {
    open

    x := addRec(["dis":"X", "n":n(0)])
    xr := folio.index.rec(x.id)
    folio.store.sync
    verifyEq(xr.numWrites, 1)

    // verify numWrite updates for each write
    (1..3).each |i|
    {
      x = commit(x, ["n":n(i)])
      folio.store.sync
      verifyEq(xr.numWrites, 1+i)
    }
    x = readById(x.id)
    verifyEq(x->n, n(3))


    // verify transients don't write
    x = commit(x, ["foo":"t"], Diff.transient)
    folio.store.sync
    verifyEq(xr.numWrites, 4)

    // add y
    y := addRec(["dis":"Y", "n":n(0)])
    yr := folio.index.rec(y.id)
    folio.store.sync
    verifyEq(yr.numWrites, 1)

    // verify coalescing
    folio.store.send(Msg(MsgId.testSleep, 200ms))
    100.times |i|
    {
      x = commit(x, ["n":n(i)])
      y = commit(y, ["n":n(i+100)])
    }
    folio.store.sync
    verifyEq(readById(x.id)->n, n(99))
    verifyEq(readById(y.id)->n, n(199))
    verifyEq(xr.numWrites, 5)
    verifyEq(yr.numWrites, 2)

    // reopen and verify
    reopen
    xr = folio.index.rec(x.id)
    yr = folio.index.rec(y.id)
    verifyEq(readById(x.id)->n, n(99));
    verifyEq(readById(y.id)->n, n(199))
    verifyEq(xr.numWrites, 0)
    verifyEq(yr.numWrites, 0)
  }
}