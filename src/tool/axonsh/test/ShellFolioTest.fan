//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jul 2026  Matthew Giannini  Creation
//

using concurrent
using xeto
using haystack
using folio

**
** ShellFolioTest
**
class ShellFolioTest : HaystackTest
{

  private ShellFolio? folio

  override Void setup()
  {
    folio = ShellFolio(FolioConfig
    {
      it.name = "axonsh-test"
      it.dir  = this.tempDir
      it.pool = ActorPool { it.name = "ShellFolioTest" }
    })
  }

  override Void teardown()
  {
    folio?.close
    folio = null
  }

  ** ShellFolio previously threw UnsupportedErr from doReadRecById, which
  ** made every readById/readRecById route unusable in the shell.
  Void testReadById()
  {
    a := folio.commit(Diff.makeAdd(["dis":"Alpha"])).newRec

    verifyDictEq(folio.readById(a.id), a)
    verifyDictEq(folio.readById(a.id, false), a)
    verifyDictEq(folio.readByIdsList([a.id]).first, a)
    verifyNotNull(folio.readRecById(a.id))
    verifyDictEq(folio.readRecById(a.id).dict, a)

    // unknown id
    verifyEq(folio.readById(Ref.gen, false), null)
    verifyErr(UnknownRecErr#) { folio.readById(Ref.gen) }
  }

  ** Trash exclusion moved into the Folio base class, so ShellFolio no
  ** longer filters it itself; verify every by-id read still hides it.
  Void testTrash()
  {
    a := folio.commit(Diff.makeAdd(["dis":"Alpha"])).newRec
    b := folio.commit(Diff.makeAdd(["dis":"Beta", "trash":Marker.val])).newRec

    // trash is invisible to normal reads
    verifyEq(folio.readById(b.id, false), null)
    verifyErr(UnknownRecErr#) { folio.readById(b.id) }
    verifyEq(folio.readByIdsList([b.id], false).first, null)
    verifyEq(folio.readRecById(b.id, false), null)
    verifyEq(folio.readAllList(Filter.has("dis")).size, 1)

    // but reachable via readByIdTrash and readTrash
    verifyDictEq(folio.readByIdTrash(a.id), a)
    verifyDictEq(folio.readByIdTrash(b.id), b)
    verifyEq(folio.readTrash(Filter.has("dis")).size, 1)

    // untrash and it comes back
    folio.commit(Diff(b, ["trash":None.val]))
    verifyNotNull(folio.readById(b.id, false))
  }

  ** ShellFolio has no persistent/transient split, so it takes FolioRec's
  ** defaults.  These used to throw UnsupportedErr from the Folio base class,
  ** which broke FolioUtil.stripUncommittable in the shell.
  Void testTagReads()
  {
    a := folio.commit(Diff.makeAdd(["dis":"Alpha"])).newRec
    b := folio.commit(Diff.makeAdd(["dis":"Beta", "trash":Marker.val])).newRec

    verifyDictEq(folio.readByIdPersistentTags(a.id), a)
    verifyEq(folio.readByIdTransientTags(a.id).isEmpty, true)
    verifyDictEq(FolioUtil.stripUncommittable(folio, a), Etc.dictRemove(a, "mod"))

    // trash and unknown recs are invisible like every other by-id read
    verifyNull(folio.readByIdPersistentTags(b.id, false))
    verifyNull(folio.readByIdTransientTags(Ref.gen, false))
    verifyErr(UnknownRecErr#) { folio.readByIdPersistentTags(b.id) }
    verifyErr(UnknownRecErr#) { folio.readByIdTransientTags(Ref.gen) }
  }

  ** ShellFolio never authorized commits before the checks moved into the
  ** Folio base class; it inherits them now.
  Void testCommitPerms()
  {
    a := folio.commit(Diff.makeAdd(["dis":"A"])).newRec
    b := folio.commit(Diff.makeAdd(["dis":"B"])).newRec

    Actor.locals[ActorContext.actorLocalsKey] = ShellDenyContext([a.id])
    try
    {
      verifyErr(PermissionErr#) { folio.commit(Diff(a, ["foo":"x"])) }

      folio.commit(Diff(b, ["foo":"x"]))
      verifyEq(folio.readById(b.id)["foo"], "x")

      // adds have no old rec so they bypass the check
      verifyEq(folio.commit(Diff.makeAdd(["dis":"C"])).newRec->dis, "C")
    }
    finally Actor.locals.remove(ActorContext.actorLocalsKey)
  }

}

**************************************************************************
** ShellDenyContext
**************************************************************************

** Context which denies writes to a fixed set of ids
internal class ShellDenyContext : FolioContext
{
  new make(Ref[] denies) { this.denies = denies }

  const Ref[] denies

  override Bool canRead(Dict r) { true }

  override Bool canWrite(FolioWrite w)
  {
    rec := w.oldRec
    return rec == null || !denies.contains(rec.id)
  }

  override Obj? commitInfo() { "shell-deny" }
}

