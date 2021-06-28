//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Sep 2016  Brian Frank  Creation
//

using concurrent
using haystack
using folio

**
** Namespace testing
**
class NsTest : AbstractFolioTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////


  Void test() { fullImpls }
  Void doTest()
  {
    verifyErr(ArgErr#) { open(toConfig("bad ns:")) }
    verifyErr(ArgErr#) { open(toConfig("bad ns" )) }

    open(toConfig("u:"))
    verifyEq(folio.idPrefix, "u:")

    // add a rec with def id, rel id, abs id
    a := addRec(["id":Ref("a"), "dis":"Alpha"])
    b := addRec(["dis":"Beta"])
    bRel := b.id.toStr[2..-1]
    verifyErr(InvalidRecIdErr#) { addRec(["id":Ref("u:c"), "dis":"Bad"]) }
    verifyErr(InvalidRecIdErr#) { addRec(["id":Ref("foo:c"), "dis":"Bad"]) }
    verifyRefEq(a.id, Ref("u:a", "Alpha"))
    verify(b.id.id.startsWith("u:"))

    // lookup abs and rel
    verifyDictEq(folio.readById(Ref("u:a")), a)
    verifyDictEq(folio.readById(Ref("a")), a)
    verifyDictEq(folio.readById(b.id), b)
    verifyDictEq(folio.readById(Ref(bRel)), b)

    // make some commits with abs id
    diff := folio.commit(Diff(Etc.makeDict(["id":Ref("u:a"), "mod":a->mod]), ["foo":"one"]))
    a = folio.readById(a.id)
    verifyDictEq(a, diff.newRec)
    verifyRefEq(diff.id, Ref("u:a", "Alpha"))
    verifyEq(a["foo"], "one")

    // make commit with rel id
    diff = folio.commit(Diff(Etc.makeDict(["id":Ref("a"), "mod":a->mod]), ["foo":"two"]))
    a = folio.readById(a.id)
    verifyDictEq(a, diff.newRec)
    verifyRefEq(diff.id, Ref("u:a", "Alpha"))
    verifyEq(folio.readById(a.id)["foo"], "two")

    // commit some ref tags
    diff = folio.commit(Diff.makeAdd(["aAbsRef":a.id, "bAbsRef":b.id, "aRelRef":Ref("a"), "bRelRef":(Ref(bRel)), "xRef":Ref("x:foo", "Keep"), "nRef":Ref.nullRef]))
    c := folio.readById(diff.id)
    verifyDictEq(diff.newRec, c)
    checkTags := |Bool reboot|
    {
      a = folio.readById(a.id)
      c = folio.readById(c.id)
      verifyRefEq(a.id, Ref("u:a", "Alpha"))
      verifySame(a.id, c->aAbsRef)
      verifySame(a.id, c->aRelRef)
      verifyRefEq(c->aAbsRef, a.id)
      verifyRefEq(c->aRelRef, a.id)
      verifyRefEq(c->bAbsRef, b.id)
      verifyRefEq(c->bRelRef, b.id)
      verifyRefEq(c->xRef, Ref("x:foo", null))
      verifyRefEq(c->nRef, Ref.nullRef)
    }
    checkTags(false)

    // close and reopen with same ns
    close
    open(toConfig("u:"))
    checkTags(true)
    close

    // close and reopen with different ns
    open(toConfig("xyz:"))
    a = folio.readById(Ref(a.id.segs.last.body))
    b = folio.readById(Ref(b.id.segs.last.body))
    c = folio.readById(Ref(c.id.segs.last.body))
    verifyRefEq(a.id, Ref("xyz:a", "Alpha"))
    verifyRefEq(b.id, Ref("xyz:$bRel", "Beta"))
    verify(b.id.toStr.startsWith("xyz:"))

    // make some changes
    diff = folio.commit(Diff(c, [
       "aAbsRef":Ref("xyz:a"), "aRelRef":Ref("a"),
       "nAbsRef":Ref("xyz:n", "Ignore"), "nRelRef":Ref("n", "Ignore"),
       "yRef":Ref("u:y")]))
    c = folio.readById(c.id)
    verifyDictEq(c, diff.newRec)
    verifyRefEq(a.id, Ref("xyz:a", "Alpha"))
    verifySame(a.id, c->aAbsRef)
    verifySame(a.id, c->aRelRef)
    verifyRefEq(c->nAbsRef, Ref("xyz:n"))
    verifyRefEq(c->nRelRef, Ref("xyz:n"))
    verifyRefEq(c->xRef, Ref("x:foo"))
    verifyRefEq(c->yRef, Ref("u:y"))


    // update a
    diff = folio.commit(Diff(a, ["dis":"Alpha x 2"]))
    a = folio.readById(a.id)
    c = folio.readById(c.id)
    verifyRefEq(a.id, Ref("xyz:a", "Alpha x 2"))
    verifySame(a.id, c->aAbsRef)
    verifySame(a.id, c->aRelRef)
  }

}

