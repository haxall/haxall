//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//  25 Nov 2025  Matthew Giannini Creation
//

using concurrent
using xeto
using xetom
using haystack

**
** CompSpaceEditTest
**
** TODO: more tests around error conditions once we settle on design philosophy for that
**
class CompSpaceEditTest: AbstractXetoTest
{
  override Void setup()
  {
    super.setup

    ns := createNamespace(CompTest.loadTestLibs)
    this.cs = CompSpace(ns).load(loadBasicXeto)
    Actor.locals[CompSpace.actorKey] = cs
    cs.start

    addRef = cs.root.get("add")->id
    c1Ref = cs.root.get("c1")->id
    c2Ref = cs.root.get("c2")->id
  }

  override Void teardown()
  {
    super.teardown
    Actor.locals.remove(CompSpace.actorKey)
  }

  CompSpace? cs
  Ref? addRef
  Ref? c1Ref
  Ref? c2Ref

  static Str loadBasicXeto()
  {
     Str<|@root: TestFolder {
            c1 @c1:  TestCounter {}
            c2 @c2:  TestCounter {}
            add @add: TestAdd {}
          }|>
  }

  CompSpaceEdit? edit(CompSpace cs) { ((MCompSpaceSpi)cs.spi).edit }

  Void testLink()
  {
    add := cs.readById(addRef)
    verifyFalse(add.links.isLinked("in1"))
    edit(cs).link(c1Ref, "out", addRef, "in1")
    links := add.links.listOn("in1")
    verifyEq(links.size, 1)
    verifyDictEq(Etc.link(c1Ref, "out"), links.first)
  }

  Void testUnlink()
  {
    add := cs.readById(addRef)
    edit(cs).link(c1Ref, "out", addRef, "in1")
    verify(add.links.isLinked("in1"))
    edit(cs).unlink(c1Ref, "out", addRef, "in1")
    verifyFalse(add.links.isLinked("in1"))
  }

  Void testCreateAndDelete()
  {
    comp := edit(cs).create(cs.root.id, "hx.test.xeto::TestCounter")
    verifyEq(comp.typeof, TestCounter#)

    // link it up
    edit(cs).link(comp.id, "out", addRef, "in1")

    // delete the comp
    edit(cs).delete(comp.id)
    verifyNull(cs.readById(comp.id, false))

    // links should be removed also
    add := cs.readById(addRef)
    verifyFalse(add.links.isLinked("in1"))

    // should be able to remove an id that doesn't exist
    edit(cs).delete(comp.id)
    verify(true)

    // cannot remove root
    verifyErr(Err#) { edit(cs).delete(cs.root.id) }
  }

  Void testUpdate()
  {
    diff := Etc.dict2("in1", TestVal(100), "ignore", "X")
    add := edit(cs).update(addRef, diff)
    verifyEq(add.get("in1"), TestVal(100))
    verifyNull(add.get("ignore"))
  }

  Void testDuplicate()
  {
    // duplicate single comp
    ids   := [cs.root.get("c1")->id]
    dups  := edit(cs).duplicate(ids)
    verifyEq(dups.size, 1)
    c1Dup := dups.first
    verifyType(c1Dup, TestCounter#)
    verifyNotEq(c1Dup.id, ids.first)

    // duplicate multiple comps
    ids  = [cs.root.get("c2")->id, cs.root.get("add")->id]
    dups = edit(cs).duplicate(ids)
    verifyEq(dups.size, 2)
    verifyType(dups.first, TestCounter#)
    verifyType(dups.last, TestAdd#)
  }

}

