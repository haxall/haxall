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
** CommitTest
**
class CommitTest : WhiteboxTest
{

  Void test()
  {
    open

    // add our record
    a := addRec(["dis":"A"])

    // make persistent change
    a = verifyCommit(a, ["foo":"bar"], 0, ["dis":"A", "foo":"bar"], [:])

    // make transient change
    a = verifyCommit(a, ["curVal":n(75), "curStatus":"ok", "baz":m], Diff.transient,
          ["dis":"A", "foo":"bar"], ["curVal":n(75), "curStatus":"ok", "baz":m])

    // verify special tags (DiffErr)
    verifyCommitErr(a, ["id":Ref.gen], "never")
    verifyCommitErr(a, ["mod":DateTime.nowUtc], "never")
    verifyCommitErr(a, ["hisEnd":DateTime.now], "never")
    verifyCommitErr(a, ["dis":"A!"], "persistentOnly")
    verifyCommitErr(a, ["site":"A!"], "persistentOnly")
    verifyCommitErr(a, ["writeVal":n(3)], "transientOnly")
    verifyCommitErr(a, ["hisStatus":"bad"], "transientOnly")

    // verify persistent/transient tag override (CommitErr)
    verifyErr(CommitErr#) { commit(a, ["foo":"!"], Diff.transient) }
    verifyErr(CommitErr#) { commit(a, ["foo":Remove.val], Diff.transient) }
    verifyErr(CommitErr#) { commit(a, ["baz":"!"], 0) }
    verifyErr(CommitErr#) { commit(a, ["baz":Remove.val], 0) }

    // verify nothing changed from errors
    a = verifyCommit(a, [:], 0,
          ["dis":"A", "foo":"bar"], ["curVal":n(75), "curStatus":"ok", "baz":m])

    // remove persistent tag
    a = verifyCommit(a, ["foo":Remove.val, "newP":m], 0,
          ["dis":"A", "newP":m], ["curVal":n(75), "curStatus":"ok", "baz":m])

    // remove transient tag
    a = verifyCommit(a, ["baz":Remove.val], Diff.transient,
          ["dis":"A", "newP":m], ["curVal":n(75), "curStatus":"ok"])

    // reopen and verify transient's gone
    reopen
    Actor.sleep(100ms)
    a = verifyCommit(a, [:], 0,
          ["dis":"A", "newP":m], [:])

    close
  }

  Dict verifyCommit(Dict rec, Obj changes, Int flags, Str:Obj persistent, Str:Obj transient)
  {
    id := rec.id
    r := folio.index.rec(rec.id)
    oldMod := (DateTime)rec->mod
    oldTicks := r.ticks
    oldPersistent := r.persistent
    oldTransient := r.transient
    isTransient := flags != 0

    rec = folio.commit(Diff(rec, changes, flags)).newRec
    verifySame(rec, folio.readById(id))
    verifySame(rec, r.dict)

    // verify mod/ticks
    newMod := (DateTime)rec->mod
    newTicks := r.ticks
    verify(newTicks > oldTicks)
    if (!isTransient) verify(newMod > oldMod, "$rec | $newMod / $oldMod")

    // persistent and transient
    verifyDictEq(r.persistent, persistent.dup.add("id", id).add("mod", newMod))
    verifyDictEq(r.transient, transient)
    if (isTransient)
      verifySame(r.persistent, oldPersistent)
    else
      verifySame(r.transient, oldTransient)
    if (transient.isEmpty) verifySame(r.dict, r.persistent)

    // merged dict
    merge := Str:Obj[:]
    merge.add("id", id).add("mod", newMod)
    persistent.each |v, n| { merge.add(n, v) }
    transient.each |v, n| { merge.add(n, v) }
    verifyDictEq(rec, merge)

    return rec
  }

  Void verifyCommitErr(Dict rec, Obj changes, Str mode)
  {
    p := false
    t := false
    switch (mode)
    {
      case "never":          p = t = true
      case "persistentOnly": t = true
      case "transientOnly":  p = true
      default:               fail
    }
    if (p) verifyErr(DiffErr#) { commit(rec, changes) }
    if (t) verifyErr(DiffErr#) { commit(rec, changes, Diff.transient) }
  }

//////////////////////////////////////////////////////////////////////////
// Trash
//////////////////////////////////////////////////////////////////////////

  Void testTrash()
  {
    open

    // add some records
    a := addRec(["dis":"A", "foo":n(1)])
    b := addRec(["dis":"B", "foo":n(2)])
    c := addRec(["dis":"C", "foo":n(3), "trash":m])
    d := addRec(["dis":"C", "foo":n(4), "trash":m])
    verifyTrash(a, false)
    verifyTrash(b, false)
    verifyTrash(c, true)
    verifyTrash(d, true)

    // add trash tag
    commit(b, ["trash":m])
    verifyTrash(a, false)
    verifyTrash(b, true)
    verifyTrash(c, true)
    verifyTrash(d, true)

    // remove trash tag
    commit(c, ["trash":Remove.val])
    verifyTrash(a, false)
    verifyTrash(b, true)
    verifyTrash(c, false)
    verifyTrash(d, true)

    // restart and verify again
    reopen
    verifyTrash(a, false)
    verifyTrash(b, true)
    verifyTrash(c, false)
    verifyTrash(d, true)

    close
  }

  Void verifyTrash(Dict r, Bool isTrash)
  {
    verifyEq(folio.index.rec(r.id).isTrash, isTrash)

    // non-option reads
    f :=  Filter("foo==${r->foo}")
    if (isTrash)
    {
      verifyEq(folio.readById(r.id, false), null)
      verifyEq(folio.readAll(f).size, 0)
      verifyEq(folio.readCount(f), 0)
      verifyEq(folio.read(f, false), null)
    }
    else
    {
      r = folio.readById(r.id)
      verifyEq(r.has("trash"), false)
      verifyEq(folio.readAll(f).size, 1)
      verifyEq(folio.readAll(f)[0]->id, r.id)
      verifyEq(folio.readCount(f), 1)
      verifyDictEq(folio.read(f, false), r)
    }

    // with opts
    opts := Etc.makeDict(["trash":m])
    verifyEq(folio.readAll(f, opts).size, 1)
    verifyEq(folio.readAll(f, opts)[0]->id, r.id)
    verifyEq(folio.readCount(f, opts), 1)
  }



}

