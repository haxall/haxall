//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2012  Brian Frank  Creation
//    4 Mar 2016  Brian Frank  Refactor for 3.0
//

using concurrent
using xeto
using haystack
using folio
using hx

**
** WatchTest
**
class WatchTest : HxTest
{

  @HxRuntimeTest
  Void testLifecycle()
  {
    t := Duration.now
    a := addRec(["dis":"a"]); aId := a.id
    b := addRec(["dis":"b"]); bId := b.id
    c := addRec(["dis":"c"]); cId := c.id

    // not found
    verifyEq(rt.watch.list.size, 0)
    verifyNull(rt.watch.get("bad one", false), null)
    verifyErr(UnknownWatchErr#) { x := rt.watch.get("bad one") }
    verifyErr(UnknownWatchErr#) { x := rt.watch.get("bad one", true) }

    // open
    w := rt.watch.open("foobar")
    verifyEq(w.dis, "foobar")
    verifyEq(w.lastPoll, 0ms); verify(w.lastPoll < Duration.now)
    verify(w.lastRenew > t-200ms); verify(w.lastRenew < Duration.now)
    w.poll
    verify(w.lastPoll > t-200ms); verify(w.lastPoll < Duration.now)
    verify(w.lastRenew > t-200ms); verify(w.lastRenew < Duration.now)
    verifyEq(w.isClosed, false)
    verifyEq(Watch[,].addAll(rt.watch.list),[w])
    verifySame(rt.watch.get(w.id), w)
    verifyEq(w.list, Ref[,])
    verifyEq(w.isEmpty, true)

    // add/remove some ids
    bad := Ref.gen
    w.addAll([bId, bad, cId])
    verifyEq(w.list.sort, [bId, cId, bad].sort)
    w.remove(bad)
    verifyEq(w.list.sort, [bId, cId].sort)
    w.addAll([aId, bId])
    verifyEq(w.list.sort, [aId, bId, cId].sort)
    w.removeAll([aId, cId, Ref.gen])
    verifyEq(w.list.sort, [bId].sort)
    w.removeAll([bId, cId])
    verifyEq(w.list, Ref[,])
    w.addAll([aId, bId])
    verifyEq(w.list.sort, [aId, bId].sort)
    verifyEq(w.isEmpty, false)

    // set
    w.set([bId, cId])
    verifyEq(w.list.sort, [bId, cId].sort)
    w.set([aId, bId])
    verifyEq(w.list.sort, [aId, bId].sort)

    // isWatched / watchesOn
    none := Watch[,]
    verifyWatches(Ref.gen, none)
    verifyWatches(aId, [w])
    verifyWatches(bId, [w])
    verifyWatches(cId, none)
    w.add(cId)

    // poll no changes
    w.poll
    Actor.sleep(40ms)
    t = Duration.now
    p := w.poll
    verify(w.lastRenew > t)
    verify(w.lastPoll > t)
    verifyEq(p, Dict[,])

    // renew, no poll
    t = Duration.now
    Actor.sleep(40ms)
    w.renew
    verify(w.lastRenew > t)
    verify(w.lastPoll < t)

    // poll one change
    a = commit(a, ["change":"!"])
    t = Duration.now
    p = w.poll
    verify(w.lastPoll > t)
    verifyEq(p, Dict[a])

    // poll list of changes
    b = commit(b, ["change":"!"])
    c = commit(c, ["change":"!"], Diff.transient)
    t = Duration.now
    p = w.poll
    verify(w.lastPoll > t)
    verifyEq(p.sort, Dict[b, c].sort)

    // poll with explicit ticks
    p = w.poll
    verifyEq(p, Dict[,])
    p = w.poll(0ms)
    verifyEq(p.sort, [a, b, c].sort)

    // remove b from watch, change all and poll
    w.remove(bId)
    a = commit(a, ["foo":"!"])
    b = commit(b, ["foo":"!"])
    c = commit(c, ["foo":"!"], Diff.transient)
    p = w.poll
    verifyEq(p.sort, Dict[a, c].sort)

    // remove c from database
    commit(c, null, Diff.remove)
    p = w.poll
    verifyEq(p.sort, Dict[,])
    a = commit(a, ["foo":"#"])
    p = w.poll
    verifyEq(p, [a])

    // close
    w.close
    verifyEq(rt.watch.list.size, 0)
    verifyNull(rt.watch.get(w.id, false), null)
    verifyEq(w.isClosed, true)
    verifyErr(WatchClosedErr#) { w.list }
    verifyErr(WatchClosedErr#) { w.add(aId) }
    verifyErr(WatchClosedErr#) { w.remove(aId) }

    // isWatched / watchesOn
    verifyWatches(Ref.gen, none)
    verifyWatches(aId, none)
    verifyWatches(bId, none)
    verifyWatches(cId, none)

    // multiple watches
    w1 := rt.watch.open("w1"); w1.add(bId); verifyWatches(bId, [w1])
    w2 := rt.watch.open("w2"); w2.add(bId); verifyWatches(bId, [w1, w2])
    w3 := rt.watch.open("w3"); w3.add(bId); verifyWatches(bId, [w1, w2, w3])

    // re-add b to watch2
    w3.add(bId)
    verifyWatches(bId, [w1, w2, w3])

    // one more
    w4 := rt.watch.open("w4")
    w4.add(aId)
    verifyWatches(aId, [w4])
    verifyWatches(bId, [w1, w2, w3])

    // set lease times
    w1.lease = 100ms;  verifyEq(w1.lease, 100ms);  w1.renew
    w2.lease = 30sec;  verifyEq(w2.lease, 30sec);  w2.renew
    w3.lease = 30sec;  verifyEq(w3.lease, 30sec);  w3.renew
    w4.lease = 100ms;  verifyEq(w4.lease, 100ms);  w4.renew

    // sleep a bit and force expires check
    Actor.sleep(200ms)
    rt.watch.checkExpires

    // verify w1 and w4 were expired
    verifyEq(w1.isClosed, true)
    verifyEq(w2.isClosed, false)
    verifyEq(w3.isClosed, false)
    verifyEq(w4.isClosed, true)
    verifyEq(rt.watch.isWatched(aId), false)
    verifyWatches(aId, none)
    verifySame(rt.watch.get(w1.id, false), null)
    verifySame(rt.watch.get(w2.id, false), w2)
    verifySame(rt.watch.get(w3.id, false), w3)
    verifySame(rt.watch.get(w4.id, false), null)
  }

  Void verifyWatches(Ref id, Watch[] expected)
  {
    verifyEq(rt.watch.isWatched(id), !expected.isEmpty)

    actual := rt.watch.listOn(id).dup
    actual.sort |a, b| { a.dis <=> b.dis }
    verifyEq(actual.size, expected.size)
    actual.each |a, i| { verifySame(a, expected[i]) }
  }

}

