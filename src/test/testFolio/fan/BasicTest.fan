//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2015  Brian Frank  Creation
//

using concurrent
using haystack
using folio

**
** BasicTest
**
class BasicTest : AbstractFolioTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics() { runImpls }
  Void doTestBasics()
  {
    // initial state
    f := open
    ver := f.curVer

    // add a, b, c
    a := addRec(["dis":"A", "size":n(10)])
    b := addRec(["dis":"B", "size":n(20)])
    c := addRec(["dis":"C", "size":n(30)])
    ver = verifyCurVerChange(ver)

    // readById bad
    verifyEq(f.readById(Ref.gen, false), null)
    verifyErr(UnknownRecErr#) { f.readById(Ref.gen) }
    verifyErr(UnknownRecErr#) { f.readById(Ref.gen, true) }

    // readById good
    verifyRecSame(f.readById(c.id), c)

    // readByIdsList
    list := f.readByIdsList([a.id, Ref.gen, b.id], false)
    verifyEq(list.size, 3)
    verifyRecSame(list[0], a)
    verifyRecSame(list[1], null)
    verifyRecSame(list[2], b)
    verifyErr(UnknownRecErr#) { f.readByIdsList([a.id, Ref.gen, b.id]) }
    verifyErr(UnknownRecErr#) { f.readByIdsList([a.id, Ref.gen, b.id], true) }

    // readByIds
    grid := f.readByIds([a.id, Ref.gen, b.id], false)
    verifyEq(grid.size, 3)
    verifyDictEq(grid[0], a)
    verifyEq(list[1], null)
    verifyDictEq(grid[2], b)
    verifyErr(UnknownRecErr#) { f.readByIds([a.id, Ref.gen, b.id]) }
    verifyErr(UnknownRecErr#) { f.readByIds([a.id, Ref.gen, b.id], true) }

    // read bad
    verifyEq(f.read(Filter("bad"), false), null)
    verifyErr(UnknownRecErr#) { f.read(Filter("bad")) }
    verifyErr(UnknownRecErr#) { f.read(Filter("bad"), true) }

    // read good
    verifyRecSame(f.read(Filter("size==20")), b)
    verifyDictEq(f.read(Filter("id == $b.id.toCode")), b)
    verifyDictEq(f.read(Filter("id == $b.id.toCode and size == 20")), b)
    verifyEq(f.read(Filter("id == $b.id.toCode and size == 10"), false), null)
    verifyEq(f.read(Filter("size == 10 and id == $b.id.toCode"), false), null)

    // readAllList
    list = f.readAllList(Filter("size >= 20"))
    verifyEq(list.size, 2)
    if (list[0].id == b.id)
    {
      verifyRecSame(list[0], b)
      verifyRecSame(list[1], c)
    }
    else
    {
      verifyRecSame(list[0], c)
      verifyRecSame(list[1], b)
    }

    // readAll
    grid = f.readAll(Filter("size >= 20"))
    verifyEq(grid.size, 2)
    if (list[0].id == b.id)
    {
      verifyDictEq(list[0], b)
      verifyDictEq(list[1], c)
    }
    else
    {
      verifyDictEq(list[0], c)
      verifyDictEq(list[1], b)
    }


    // readAllEachWhile, no break
    acc := Dict[,]
    ewr := f.readAllEachWhile(Filter("size >= 20"), null) |x->Obj?| { acc.add(x); return null }
    verifyEq(ewr, null)
    verifyDictsEq(acc, [b, c], false)

    // readAllEachWhile with break
    acc2 := Dict[,]
    ewr2 := f.readAllEachWhile(Filter("size >= 20"), null) |x->Obj?| { acc2.add(x); return "break!" }
    verifyEq(ewr2, "break!")
    verifyDictsEq(acc2, acc[0..0], false)

    // readCount
    verifyEq(f.readCount(Filter("size >= 20")), 2)
    ver = verifyCurVerNoChange(ver)

    // reopen
    f = reopen
    verifyDictEq(f.readById(a.id), a)
    verifyDictEq(f.readById(b.id), b)
    verifyDictEq(f.readById(c.id), c)
    ver = f.curVer

    // make some persistent diffs
    aMod := a->mod; bMod := b->mod; cMod := c->mod;
    Actor.sleep(10ms)
    diffs := f.commitAllAsync([Diff(a, ["pchange":"ap-1"]), Diff(c, ["pchange":"cp-1"])]).diffs
    f.sync
    ver = verifyCurVerChange(ver)
    a = f.readById(a.id)
    b = f.readById(b.id)
    c = f.readById(c.id)
    verifyDictEq(a, diffs[0].newRec)
    verifyDictEq(c, diffs[1].newRec)
    verify(a->mod >  aMod)
    verify(b->mod == bMod)
    verify(c->mod >  cMod)
    verifyEq(a["pchange"], "ap-1")
    verifyEq(c["pchange"], "cp-1")

    // make another persistent change to a
    aMod = a->mod
    Actor.sleep(10ms)
    diffs = f.commitAllAsync([Diff(a, ["pchange":"ap-2"])]).diffs
    a = f.readById(a.id)
    verifyDictEq(a, diffs[0].newRec)
    verifyEq(a["pchange"], "ap-2")
    verify(a->mod > aMod)
    ver = verifyCurVerChange(ver)

    // make transient diffs to b and b
    if (impl.supportsTransient)
    {
      aMod = a->mod; bMod = b->mod; cMod = c->mod;
      diffs = f.commitAll([Diff(b, ["tchange":"bt-1"], Diff.transient), Diff(c, ["tchange":"ct-1"], Diff.transient)])
      ver = verifyCurVerNoChange(ver)
      b = f.readById(b.id)
      c = f.readById(c.id)
      verifyDictEq(b, diffs[0].newRec)
      verifyDictEq(c, diffs[1].newRec)
      verifyEq(a["pchange"], "ap-2")
      verifyEq(b["tchange"], "bt-1")
      verifyEq(c["pchange"], "cp-1")
      verifyEq(c["tchange"], "ct-1")
      verifyEq(a->mod, aMod)
      verifyEq(b->mod, bMod)
      verifyEq(c->mod, cMod)

      // reopen, and verify transient changes didn't persist
      f = reopen
      a = f.readById(a.id)
      b = f.readById(b.id)
      c = f.readById(c.id)
      ver = f.curVer
      verifyEq(a["pchange"], "ap-2")
      verifyEq(b["tchange"], null)
      verifyEq(c["pchange"], "cp-1")
      verifyEq(c["tchange"], null)
      verify(a->mod == aMod)
      verify(b->mod == bMod)
      verify(c->mod == cMod)
    }

    // modify a to generate new mod, then verify concurrent checks
    oldA := a
    oldB := b
    newA := f.commitAsync(Diff(oldA, ["change":"a-2"])).dict
    newB := f.commitAsync(Diff(oldB, ["change":"b-1"])).dict
    ver = verifyCurVerChange(ver)
    verify(newA->mod > oldA->mod)
    verify(newB->mod > oldB->mod)
    verifyErr(ConcurrentChangeErr#) { f.commitAllAsync([Diff(oldA, ["change":"X!"]), Diff(newB, ["change":"X!"])]).dicts }
    verifyErr(ConcurrentChangeErr#) { f.commitAllAsync([Diff(newA, ["change":"X!"]), Diff(oldB, ["change":"X!"])]).dicts }
    verifyErr(ConcurrentChangeErr#) { f.commitAllAsync([Diff(oldA, ["change":"X!"]), Diff(oldB, ["change":"X!"], Diff.force)]).dicts }
    verifyEq(f.readById(a.id)["change"], "a-2")
    verifyEq(f.readById(b.id)["change"], "b-1")

    // verify force flag
    f.commitAll([Diff(oldA, ["change":"a-3"], Diff.force), Diff(oldB, ["change":"b-2"], Diff.force)])
    ver = verifyCurVerChange(ver)
    verifyEq(f.readById(a.id)["change"], "a-3")
    verifyEq(f.readById(b.id)["change"], "b-2")

    // remove record
    a = f.readById(a.id)
    b = f.readById(b.id)
    c = f.readById(c.id)
    folio.commit(Diff(c, null, Diff.remove))
    ver = verifyCurVerChange(ver)
    verifyEq(f.readById(c.id, false), null)
    verifyErr(UnknownRecErr#) { f.readById(c.id) }

    // commit record that doesn't exist
    verifyErr(CommitErr#) { f.commitAll([Diff(a, ["doNotAdd":"foo"], Diff.force), Diff(c, ["foo":"bar"])]) }
    ver = verifyCurVerNoChange(ver)
    verifyEq(f.readById(a.id)["doNotAdd"], null)

    // close and reopen
    f = reopen
    verifyDictEq(f.readById(a.id), a)
    verifyDictEq(f.readById(b.id), b)
    verifyEq(f.readById(c.id, false), null)
    verifyErr(UnknownRecErr#) { f.readById(c.id) }

    // cleanup
    f.close

    // verify calls fail
    verifyErr(ShutdownErr#) { f.readById(a.id) }
    verifyErr(ShutdownErr#) { f.readByIds([a.id]) }
    verifyErr(ShutdownErr#) { f.readByIdsList([a.id]) }
    verifyErr(ShutdownErr#) { f.readCount(Filter("foo")) }
    verifyErr(ShutdownErr#) { f.read(Filter("foo")) }
    verifyErr(ShutdownErr#) { f.readAll(Filter("foo")) }
    verifyErr(ShutdownErr#) { f.readAllList(Filter("foo")) }
    verifyErr(ShutdownErr#) { f.readByIdsList([a.id]) }
    verifyErr(ShutdownErr#) { f.commit(Diff(a, ["foo":m])) }
    verifyErr(ShutdownErr#) { f.commitAll([Diff(a, ["foo":m])]) }
    verifyErr(ShutdownErr#) { f.commitAsync(Diff(a, ["foo":m])) }
    verifyErr(ShutdownErr#) { f.commitAllAsync([Diff(a, ["foo":m])]) }
  }

//////////////////////////////////////////////////////////////////////////
// FolioFuture
//////////////////////////////////////////////////////////////////////////

  Void testFolioFuture()
  {
    // add a, b, c
    a := Etc.makeDict(["dis":"A", "size":n(10)])
    b := Etc.makeDict(["dis":"B", "size":n(20)])
    c := Etc.makeDict(["dis":"C", "size":n(30)])

    FolioFuture? r

    r = FolioFuture.makeSync(ReadFolioRes("xx", true, Dict?[null]))
    verifyEq(r.count, 1)
    verifyEq(r.dict(false), null)
    verifyErr(UnknownRecErr#) { r.dict }
    verifyEq(r.dicts(false), Dict?[null])
    verifyErr(UnknownRecErr#) { r.dicts }
    verifyEq(r.grid(false).size, 0)
    verifyErr(UnknownRecErr#) { r.grid }

    // readById b
    r = FolioFuture.makeSync(ReadFolioRes("xx", false, Dict?[c]))
    verifyEq(r.count, 1)
    verifyDictEq(r.dict, c)
    verifyDictEq(r.dict(false), c)
    verifyDictsEq(r.dicts, [c])
    verifyDictsEq(r.dicts(false), [c])
    verifyEq(r.grid.size, 1)
    verifyDictEq(r.grid[0], c)

    // readByIds
    r = FolioFuture.makeSync(ReadFolioRes("xx", true, Dict?[a, null, b]))
    verifyEq(r.count, 3)
    verifyDictEq(r.dict, a)
    verifyDictEq(r.dict(false), a)
    verifyEq(r.dicts(false).size, 3)
    verifySame(r.dicts(false)[0], a)
    verifySame(r.dicts(false)[1], null)
    verifySame(r.dicts(false)[2], b)
    verifyErr(UnknownRecErr#) { r.dicts }
    verifyErr(UnknownRecErr#) { r.dicts(true) }
    verifyErr(UnknownRecErr#) { r.grid }
    verifyEq(r.grid(false).size, 3)
    verifyDictEq(r.grid(false)[0], a)
    verifyDictEq(r.grid(false)[1], Etc.emptyDict)
    verifyDictEq(r.grid(false)[2], b)

    // read bad
    r = FolioFuture.makeSync(ReadFolioRes("xx", false, Dict[,]))
    verifyEq(r.count, 0)
    verifyEq(r.dict(false), null)
    verifyErr(UnknownRecErr#) { r.dict }
    verifyEq(r.dicts, Dict[,])
    verifyEq(r.dicts(false), Dict[,])
    verifyEq(r.dicts(true), Dict[,])
    verifyEq(r.grid(false).size, 0)
    verifyEq(r.grid(true).size, 0)

    // read
    r = FolioFuture.makeSync(ReadFolioRes("xx", false, Dict[b]))
    verifyEq(r.count, 1)
    verifyDictEq(r.dict, b)
    verifySame(r.dict(false), b)
    verifyEq(r.dicts, Dict[b])
    verifyEq(r.grid.size, 1)
    verifyDictEq(r.grid[0], b)
    verifyErr(UnsupportedErr#) { r.diffs }

    // readAll
    r = FolioFuture.makeSync(ReadFolioRes("xx", false, Dict[b, c]))
    verifyEq(r.count, 2)
    verifyEq(r.dicts.size, 2)
    verifyEq(r.grid.size, 2)
    if (r.dicts[0] === b)
    {
      verifySame(r.dict, b)
      verifySame(r.dicts[0], b)
      verifySame(r.dicts[1], c)
      verifyDictEq(r.grid[0], b)
      verifyDictEq(r.grid[1], c)
    }
    else
    {
      verifySame(r.dict, c)
      verifySame(r.dicts[0], c)
      verifySame(r.dicts[1], b)
      verifyDictEq(r.grid[0], c)
      verifyDictEq(r.grid[1], b)
    }

    r = FolioFuture.makeSync(CountFolioRes(2))
    verifyEq(r.count, 2)
    verifyErr(UnsupportedErr#) { r.dict }
    verifyErr(UnsupportedErr#) { r.dicts }
    verifyErr(UnsupportedErr#) { r.grid }
    verifyErr(UnsupportedErr#) { r.diffs }
  }

//////////////////////////////////////////////////////////////////////////
// Filters
//////////////////////////////////////////////////////////////////////////

  Void testFilters() { runImpls }
  Void doTestFilters()
  {
    open

    a := addRec(["dis":"a", "num":n(10)])
    b := addRec(["dis":"b", "num":n(20), "ref":a.id])
    c := addRec(["dis":"c", "num":n(30), "ref":a.id])
    d := addRec(["dis":"d", "num":n(40), "ref":[a.id]])
    e := addRec(["dis":"e", "num":n(50), "ref":[a.id, b.id]])
    f := addRec(["dis":"f", "refx":[d.id]])
    g := addRec(["dis":"g", "refx":[e.id]])

    verifyFilter("dis", [a, b, c, d, e, f, g])
    verifyFilter("ref", [b, c, d, e])
    verifyFilter("not ref", [a, f, g])

    verifyFilter("num == 20", [b])
    verifyFilter("num < 30",  [a, b])
    verifyFilter("num >= 30", [c, d, e])

    verifyFilter("ref == @bad", [,])
    verifyFilter("ref == $a.id.toCode", [b, c, d, e])

    verifyFilter("ref->num", [b, c, d, e])
    verifyFilter("ref->num == 10", [b, c, d, e])

    verifyFilter("refx->ref->num == 10", [f, g])
    verifyFilter("refx->ref->num == 20", [g])
  }

  Void verifyFilter(Str filter, Dict[] expected)
  {
    actual := folio.readAll(Filter(filter)).sortDis
    a := actual.toRows.join(",") { it.dis }
    e := expected.join(",") { it.dis }
    //echo("-- $filter | $a ?= $e")
    verifyEq(a, e)
  }

//////////////////////////////////////////////////////////////////////////
// Remove Tag
//////////////////////////////////////////////////////////////////////////

  Void testRemoveTags() { runImpls }
  Void doTestRemoveTags()
  {
    f := open

    a := addRec(["foo":"f", "bar":"b", "baz":Remove.val])
    verifyDictEq(a, ["id":a.id, "mod":a->mod, "foo":"f", "bar":"b"])

    a = commit(a, ["foo":Remove.val, "bar":"b", "baz":Remove.val])
    verifyDictEq(a, ["id":a.id, "mod":a->mod, "bar":"b"])

    a = commit(a, ["bar":Remove.val])
    verifyDictEq(a, ["id":a.id, "mod":a->mod])

    verifyErr(DiffErr#) { commit(a, ["id":Remove.val]) }
    verifyErr(DiffErr#) { commit(a, ["mod":Remove.val]) }

    close
  }

//////////////////////////////////////////////////////////////////////////
// Read Opts
//////////////////////////////////////////////////////////////////////////

  Void testReadOpts() { runImpls }
  Void doTestReadOpts()
  {
    open

    a := addRec(["dis":"A", "num": n(1), "a":n(1)])
    b := addRec(["dis":"B", "num": n(2), "b":n(2)])
    c := addRec(["dis":"C", "num": n(3), "c":n(3)])
    d := addRec(["dis":"D", "num": n(4), "d":n(4)])
    e := addRec(["dis":"E", "num": n(5), "e":n(5), "trash": Marker.val])
    f := addRec(["dis":"F", "num": n(6), "f":n(6), "trash": Marker.val])

    all := verifyReadOpts("num", [:], [a, b, c, d])
    verifyReadOpts("num >= 3", [:], [c, d])

    verifyReadOpts("num", ["sort":m], [a, b, c, d], true)

    allTrash := verifyReadOpts("num", ["trash":m], [a, b, c, d, e, f])
    verifyReadOpts("num >= 3", ["trash":m], [c, d, e, f])

    verifyReadOpts("num", ["limit":n(1)], all[0..0])
    verifyReadOpts("num", ["limit":n(2)], all[0..1])
    verifyReadOpts("num", ["limit":n(3)], all[0..2])
    verifyReadOpts("num", ["limit":n(4)], all[0..3])

    verifyReadOpts("num", ["limit":n(1), "trash":m], allTrash[0..0])
    verifyReadOpts("num", ["limit":n(2), "trash":m], allTrash[0..1])
    verifyReadOpts("num", ["limit":n(3), "trash":m], allTrash[0..2])
    verifyReadOpts("num", ["limit":n(4), "trash":m], allTrash[0..3])
    verifyReadOpts("num", ["limit":n(5), "trash":m], allTrash[0..4])
    verifyReadOpts("num", ["limit":n(6), "trash":m], allTrash[0..5])

    close
  }

  Dict[] verifyReadOpts(Str filterStr, Str:Obj optsMap, Dict[] expected, Bool verifyOrder := false)
  {
    opts := Etc.makeDict(optsMap)
    filter := Filter(filterStr)

    list := folio.readAllList(filter, opts)
    verifyDictsEq(list, expected, verifyOrder)

    grid := folio.readAll(filter, opts)
    verifyDictsEq(grid.toRows, expected, verifyOrder)

    count := folio.readCount(filter, opts)
    verifyEq(count, expected.size)

    return list
  }

//////////////////////////////////////////////////////////////////////////
// Trash
//////////////////////////////////////////////////////////////////////////

  Void testTrash() { runImpls }
  Void doTestTrash()
  {
    open

    a := addRec(["num": n(1), "a":n(1)]); Ref? aId := a.id
    b := addRec(["num": n(2), "b":n(2)]); Ref? bId := b.id
    c := addRec(["num": n(3), "c":n(3)]); Ref? cId := c.id
    d := addRec(["num": n(4), "d":n(4), "trash": Marker.val]); Ref? dId := d.id

    // query filters out trash by default
    set := folio.readAll(Filter("num"))
    verifyRecIds(set, [aId, bId, cId])
    verifyEq(folio.readCount(Filter("num")), 3)
    set = folio.readAll(Filter("num >= 3"))
    verifyRecIds(set, [cId])

    // readById
    verifyReadById(aId, a)
    verifyReadById(bId, b)
    verifyReadById(cId, c)
    verifyReadById(dId, null)

    // verify can use read
    verifyDictEq(folio.readAllList(Filter.eq("id", d.id), Etc.dict1("trash", m)).first, d)

    // verify readByIdTrash
    verifyDictEq(folio.readByIdTrash(aId), a)
    verifyDictEq(folio.readByIdTrash(bId), b)
    verifyDictEq(folio.readByIdTrash(cId), c)
    verifyDictEq(folio.readByIdTrash(dId), d)
    verifyEq(folio.readByIdTrash(Ref.gen, false), null)
    verifyErr(UnknownRecErr#) { folio.readByIdTrash(Ref.gen) }
    verifyErr(UnknownRecErr#) { folio.readByIdTrash(Ref.gen, true) }

    // get all tags/vals (trash should be filtered out)
    /*
    verifyReadAllTagNames("id",
      [["a",   "Number",   1],
       ["b",   "Number",   1],
       ["c",   "Number",   1],
       ["id",  "Ref",      3],
       ["mod", "DateTime", 3],
       ["num", "Number",   3]])
    verifyEq(proj.readAllTagVals("id", "num"), Obj[n(1), n(2), n(3)])
    */

    // with trash option
    optsTrash := Etc.makeDict(["trash":m])
    set = folio.readAll(Filter("num"), optsTrash)
    verifyRecIds(set, [aId, bId, cId, dId])
    set = folio.readAll(Filter("num and trash"), optsTrash)
    verifyRecIds(set, [dId])
    verifyEq(folio.readCount(Filter("num"), optsTrash), 4)
    set = folio.readAll(Filter("num >= 3"), optsTrash)
    verifyRecIds(set, [cId, dId])

    // make b and c trash, and remove d from trash
    folio.commitAll([
      Diff(b, ["trash":Marker.val]),
      Diff(c, ["trash":Marker.val]),
      Diff(d, ["trash":Remove.val])])
      d = folio.readById(dId)

    // readById
    verifyReadById(aId, a)
    verifyReadById(bId, null)
    verifyReadById(cId, null)
    verifyReadById(dId, d)

    // verify readByIdTrash
    verifyEq(folio.readByIdTrash(aId).id, aId)
    verifyEq(folio.readByIdTrash(bId).id, bId)
    verifyEq(folio.readByIdTrash(cId).id, cId)
    verifyEq(folio.readByIdTrash(dId).id, dId)

    // trash filtered
    set = folio.readAll(Filter("num"))
    verifyRecIds(set, [aId, dId])
    set = folio.readAll(Filter("num >= 3"))
    verifyRecIds(set, [dId])
    set = folio.readAll(Filter("trash"), optsTrash)
    verifyRecIds(set, [bId, cId])

    // get all tags/vals (trash should be filtered out)
    /*
    verifyReadAllTagNames("id",
      [["a",   "Number",   1],
       ["d",   "Number",   1],
       ["id",  "Ref",      2],
       ["mod", "DateTime", 2],
       ["num", "Number",      2]])
    verifyEq(proj.readAllTagVals("id", "num"), Obj[n(1), n(4)])
    */

    // get everything
    set = folio.readAll(Filter("num"), optsTrash).sortCol("num")
    verifyRecIds(set, [aId, bId, cId, dId])

    // empty trash
    verifyEq(folio.commitRemoveTrashAsync.count, 2)
    set = folio.readAll(Filter("num"), optsTrash).sortCol("num")
    verifyRecIds(set, [aId, dId])

    close
  }

//////////////////////////////////////////////////////////////////////////
// Kinds
//////////////////////////////////////////////////////////////////////////

  Void testKinds() { runImpls }
  Void doTestKinds()
  {
    open

    verifyKind(Marker.val)
    verifyKind(true)
    verifyKind(n(123, "ft"))
    verifyKind("string")
    verifyKind(Ref("abc-123"), "siteRef")
    verifyKind(`uri`)
    verifyKind(Date.today)
    verifyKind(Time.now)
    verifyKind(DateTime.now.floor(1sec))
    verifyKind([n(1), "foo"])
    verifyKind(Etc.dict2("a", n(1), "bar", "foo"))
    verifyKind(Etc.makeMapGrid(["x":m], ["y":n(123)]))
    verifyKind(Symbol("foo"))
    verifyKind(Span(Date.today))
    verifyKind(Span[Span(Date.today)])
    verifyKind(XStr("Foo", "bar"))

    verifyKindErr(NA.val)
    verifyKindErr(Version("23"))
    verifyKindErr(Buf().print("bad"))
    verifyKindErr(DateSpan.today)

    close
  }

  Void verifyKind(Obj val, Str name := "foo")
  {
    // echo("## verifyKind $name = $val [$val.typeof]")
    rec := addRec([name:val])
    verifyValEq(readById(rec.id).get(name), val)
    commit(rec, [name+"2":val])
    verifyValEq(readById(rec.id).get(name+"2"), val)
  }

  Void verifyKindErr(Obj val)
  {
    verifyErr(InvalidTagValErr#) { addRec(["foo":val]) }
    rec := addRec(["dis":"safe"])
    verifyErr(InvalidTagValErr#) { commit(rec, ["bar":val]) }
  }

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

  Void testHooks() { runImpls }
  Void doTestHooks()
  {
    open
    cx := TestContext("user")
    Actor.locals[ActorContext.actorLocalsKey] = cx

    t := TestHooks()
    folio.hooks = t

    aPre := Diff.makeAdd(["dis":"a"])
    bPre := Diff.makeAdd(["dis":"b"])
    diffs := folio.commitAll([aPre, bPre])
    aPost := diffs[0]
    bPost := diffs[1]
    verifyHooks(t, cx, [aPre, bPre], [aPost, bPost])

    cPre := Diff(aPost.newRec, ["change":"!"])
    cPost := folio.commit(cPre)
    verifyHooks(t, cx, [aPre, bPre, cPre], [aPost, bPost, cPost])

    dPre := Diff(bPost.newRec, null, Diff.remove)
    dPost := folio.commit(dPre)
    verifyHooks(t, cx, [aPre, bPre, cPre, dPre], [aPost, bPost, cPost, dPost])

    ePre := Diff(cPost.newRec, ["another":"!"], Diff.transient)
    ePost := folio.commit(ePre)
    verifyHooks(t, cx, [aPre, bPre, cPre, dPre, ePre], [aPost, bPost, cPost, dPost, ePost])

    xPre := Diff.makeAdd(["dis":"x"])
    yPre := Diff.makeAdd(["dis":"y", "throw":m])
    verifyErr(IOErr#) { folio.commitAll([xPre, yPre]) }
    verifyHooks(t, cx, [aPre, bPre, cPre, dPre, ePre, xPre, yPre], [aPost, bPost, cPost, dPost, ePost])
    verifyEq(folio.readCount(Filter("dis==\"x\"")), 0)
    verifyEq(folio.readCount(Filter("dis==\"y\"")), 0)

    if (impl.supportsHis)
    {
      tz := TimeZone("New_York")
      pt := folio.commit(Diff.makeAdd(["dis":"pt", "his":m, "point":m, "tz":tz.name, "kind":"Number"])).newRec
      date := Date("2021-08-30")
      ts1 := date.toDateTime(Time("00:00:00"), tz)
      ts2 := date.toDateTime(Time("01:00:00"), tz)
      items := [HisItem(ts1, n(1)), HisItem(ts2, n(2))]

      t.clear
      verifyEq(t.hisWrites.size, 0)
      Dict res := folio.his.write(pt.id, items).get
      verifyEq(t.hisWrites.size, 1)
      verifyEq(res["count"], n(2))
      verifyEq(res["span"], Span(ts1, ts2))
      verifySame(t.hisWrites[0], res)
      verifySame(t.cxInfoRef.val, cx.commitInfo)
    }

    Actor.locals.remove(ActorContext.actorLocalsKey)
  }

  internal Void verifyHooks(TestHooks t, FolioContext cx, Diff[] preExpected, Diff[] postExpected)
  {
    verifySame(t.cxInfoRef.val, cx.commitInfo)

    preActual := t.pres
    verifyEq(preActual.size, preExpected.size)
    preActual.each |a, i| { verifySame(a, preExpected[i]) }

    postActual := t.posts
    verifyEq(postActual.size, postExpected.size)
    postActual.each |a, i| { verifySame(a, postExpected[i]) }
  }

}

**************************************************************************
** TestContext
**************************************************************************

internal class TestContext : FolioContext
{
  new make(Obj ci) { commitInfo = ci }

  override Bool canRead(Dict r) { true }

  override Bool canWrite(Dict r) { true }

  override const Obj? commitInfo
}

**************************************************************************
** TestHooks
**************************************************************************

internal const class TestHooks : FolioHooks
{
  Void clear()
  {
    cxInfoRef.val = null
    presRef.val = Diff#.emptyList
    postsRef.val = Diff#.emptyList
    hisWritesRef.val = Dict#.emptyList
  }

  Diff[] pres() { presRef.val }
  const AtomicRef presRef := AtomicRef(Diff#.emptyList)

  Diff[] posts() { postsRef.val }
  const AtomicRef postsRef := AtomicRef(Diff#.emptyList)

  Dict[] hisWrites() { hisWritesRef.val }
  const AtomicRef hisWritesRef := AtomicRef(Dict#.emptyList)

  const AtomicRef cxInfoRef := AtomicRef()

  override Namespace? ns(Bool checked := true) { throw UnsupportedErr() }

  override Void preCommit(FolioCommitEvent e)
  {
    cxInfoRef.val = e.cxInfo
    presRef.val = pres.dup.add(e.diff).toImmutable
    if (e.diff.changes.has("throw")) throw IOErr()
  }

  override Void postCommit(FolioCommitEvent e)
  {
    cxInfoRef.val = e.cxInfo
    postsRef.val = posts.dup.add(e.diff).toImmutable
  }

  override Void postHisWrite(FolioHisEvent e)
  {
    cxInfoRef.val = e.cxInfo
    hisWritesRef.val = hisWrites.dup.add(e.result).toImmutable
  }
}

