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
  static const Ref c1Ref  := Ref("c1")
  static const Ref c2Ref  := Ref("c2")
  static const Ref addRef := Ref("add")

  static Str loadBasicXeto()
  {
     Str<|@root: TestFolder {
            @c1:  TestCounter {}
            @c2:  TestCounter {}
            @add: TestAdd {}
          }|>
  }

  Void testLink()
  {
    cs := basicSpace
    add := cs.readById(addRef)
    verifyFalse(add.links.isLinked("in1"))
    cs.edit.link(c1Ref, "out", addRef, "in1")
    links := add.links.listOn("in1")
    verifyEq(links.size, 1)
    verifyDictEq(Etc.link(c1Ref, "out"), links.first)
  }

  Void testUnlink()
  {
    cs := basicSpace
    add := cs.readById(addRef)
    cs.edit.link(c1Ref, "out", addRef, "in1")
    verify(add.links.isLinked("in1"))
    cs.edit.unlink(c1Ref, "out", addRef, "in1")
    verifyFalse(add.links.isLinked("in1"))
  }

  Void testCreateAndDelete()
  {
    cs := basicSpace
    comp := cs.edit.create("hx.test.xeto::TestCounter")
    verifyEq(comp.typeof, TestCounter#)

    // link it up
    cs.edit.link(comp.id, "out", addRef, "in1")

    // delete the comp
    cs.edit.delete(comp.id)
    verifyNull(cs.readById(comp.id, false))

    // links should be removed also
    add := cs.readById(addRef)
    verifyFalse(add.links.isLinked("in1"))

    // should be able to remove an id that doesn't exist
    cs.edit.delete(comp.id)
    verify(true)

    // cannot remove root
    verifyErr(Err#) { cs.edit.delete(Ref("root")) }
  }

  Void testUpdate()
  {
    cs := basicSpace
    diff := Etc.dict2("in1", TestVal(100), "ignore", "X")
    add := cs.edit.update(addRef, diff)
    verifyEq(add.get("in1"), TestVal(100))
    verifyNull(add.get("ignore"))
  }

  private CompSpace basicSpace()
  {
    ns := createNamespace(CompTest.loadTestLibs)
    cs := CompSpace(ns).load(loadBasicXeto)
    Actor.locals[CompSpace.actorKey] = cs
    cs.start
    return cs
  }
}