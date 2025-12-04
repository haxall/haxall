//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Feb 2016  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hxStore

**
** Commit handles the internal pipeline to a commit a Diff
** always processed on the IndexMgr actor thread:
**   - Rec: updates to persistent/transient tags
**   - IndexMgr: updates to in-memory indexing
**   - StoreMgr: fires off writes to blob storage
**   - DisMgr: fires off changes to record display string
**   - FolioHooks: fires off pre/post commit callbacks
**
internal class Commit
{
  new make(HxFolio folio, Diff diff, DateTime newMod, Int newTicks, [Ref:Ref]? newIds, Obj? cxInfo)
  {
    this.folio       = folio
    this.index       = folio.index
    this.store       = folio.store
    this.inDiff      = diff
    this.isTransient = diff.isTransient
    this.oldMod      = inDiff.oldMod
    this.newMod      = diff.isTransient ? oldMod : newMod
    this.newTicks    = newTicks
    this.newIds      = newIds
    this.cxInfo      = cxInfo
    this.oldRec      = index.rec(diff.id, false)
    if (oldRec == null)
    {
      this.id = normRef(diff.id)
    }
    else
    {
      this.id      = oldRec.id
      this.oldDict = oldRec.dict
    }
    this.event = CommitEvent(diff, oldDict, cxInfo)
  }

  Void verify()
  {
    if (inDiff.isAdd)
    {
      // if add, verify record does not exists
      if (oldRec != null) throw CommitErr("Rec already exists: $id")
    }
    else
    {
      // verify record exists
      if (oldRec == null) throw CommitErr("Rec not found: $id")

      // unless the force flag was specified check for
      // concurrent change errors
      if (!inDiff.isForce && oldRec.dict->mod != oldMod)
        throw ConcurrentChangeErr("$id: ${oldRec.dict->mod} != $oldMod")

      // make sure no transient tags overwrite persistent and vise versa
      inDiff.changes.each |v, n|
      {
        if (isTransient)
        {
          if (oldRec.persistent.has(n))
            throw CommitErr("Cannot update persistent tag transiently: $n")
        }
        else
        {
          if (oldRec.transient.has(n))
            throw CommitErr("Cannot update transient tag persistently: $n")
        }
      }
    }

    // pre-commit hook
    folio.hooks.preCommit(event)
  }

  Diff apply()
  {
    normTags

    if (inDiff.isAdd) add
    else if (inDiff.isRemove) remove
    else if (isTransient) updateTransient
    else updatePersistent

    this.outDiff = Diff(id, oldMod, oldDict, newMod, newRec?.dict, inDiff.changes, inDiff.flags)

    event.diff = outDiff
    folio.hooks.postCommit(event)

    stats := isTransient ? folio.stats.commitsTransient : folio.stats.commitsPersistent
    stats.add(Duration.nowTicks - newTicks)

    return outDiff
  }

//////////////////////////////////////////////////////////////////////////
// Tag Normalization
//////////////////////////////////////////////////////////////////////////

  private Void normTags()
  {
    inDiff.changes.each |v, n|
    {
      if (n == "tz" || n == "unit") hisTagsModified = true
      tags[n] = normVal(v)
    }
  }

  private Obj? normVal(Obj? v)
  {
    if (inDiff.isSkipRefNorm) return v
    return Etc.mapRefs(v) |ref| { normRef(ref) }
  }

  private Ref normRef(Ref ref)
  {
    // ensure absolute
    ref = folio.toAbsRef(ref)

    // check for existing rec
    rec := index.rec(ref, false)
    if (rec != null) return rec.id

    // check for ids we are adding
    if (newIds != null)
    {
      newId := newIds[ref]
      if (newId != null) return newId
    }

    // strip display
    ref = ref.noDis

    return ref
  }

//////////////////////////////////////////////////////////////////////////
// Add/Update/Remove
//////////////////////////////////////////////////////////////////////////

  private Void add()
  {
    // strip Remove.val
    tags = tags.findAll |v| { v != Remove.val }

    // finialize persistent Dict and create blob
    tags["id"] = id
    tags["mod"] = newMod
    this.newRec = store.add(Etc.makeDict(tags)) // add to store synchrously

    // update index
    indexAdd(index, newRec)
  }

  private Void updatePersistent()
  {
    // finalize persistent Dict
    acc := mergeChanges(oldRec.persistent)
    acc["id"] = oldRec.id
    acc["mod"] = newMod
    newPersistent := Etc.makeDict(acc)

    // update index and Rec
    newRec = oldRec
    indexUpdate(index, newRec, oldDict, newPersistent, newTicks, tags)

    // check for tags which might modify his items
    if (hisTagsModified) index.hisTagsModified(newRec)

    // update blob asynchronously
    store.update(newRec)
  }

  private Void updateTransient()
  {
    newTransient := Etc.makeDict(mergeChanges(oldRec.transient))
    newRec = oldRec
    newRec.updateDict(newRec.persistent, newTransient, newTicks)
  }

  private Str:Obj mergeChanges(Dict orig)
  {
    acc := Str:Obj[:]
    orig.each |v, n| { acc[n] = v }
    this.tags.each |v, n|
    {
      if (v === Remove.val)
      {
        acc.remove(n)
      }
      else
      {
        acc[n] = v
      }
    }
    return acc
  }

  private Void remove()
  {
    // remove from index
    indexRemove(index, oldRec)

    // remove blob (and all dependent blobs)
    store.remove(oldRec)
  }

//////////////////////////////////////////////////////////////////////////
// Tag Indexing
//////////////////////////////////////////////////////////////////////////

  static Void indexAdd(IndexMgr index, Rec newRec)
  {
    // update id index (use add to double check the id is unique)
    index.byId.add(newRec.id, newRec)
  }

  static Void indexUpdate(IndexMgr index, Rec rec, Dict oldDict, Dict newDict, Int newTicks, [Str:Obj?]? tags)
  {
    // update Rec atomic refs
    oldIsTrash := rec.isTrash
    rec.updateDict(newDict, rec.transient, newTicks)
    newIsTrash := rec.isTrash

    // update display strings
    index.folio.disMgr.update(rec)
  }

  static Void indexRemove(IndexMgr index, Rec rec)
  {
    folio := index.folio
    dict := rec.persistent

    // remove file
    folio.file.get(dict.id, false)?.delete

    // clear Ref.dis
    rec.id.disVal = null

    // remove from id index
    index.byId.remove(rec.id)

    // update dis strings
    folio.disMgr.updateAll
  }

//////////////////////////////////////////////////////////////////////////
// Field
//////////////////////////////////////////////////////////////////////////

  const HxFolio folio           // make
  const IndexMgr index          // make
  const StoreMgr store          // make
  const Ref id                  // make
  const Bool isTransient        // make
  const Diff inDiff             // make
  const Rec? oldRec             // make
  const Dict? oldDict           // make
  const DateTime? oldMod        // make
  const DateTime newMod         // make
  const Int newTicks            // make
  const Obj? cxInfo             // make
  private CommitEvent event     // make
  private [Ref:Ref]? newIds     // make
  private Str:Obj tags := [:]   // normTags
  private Bool hisTagsModified  // normTags
  private Rec? newRec           // add/remove/updateX
  private Diff? outDiff         // apply
}

**************************************************************************
** CommitEvent
**************************************************************************

internal class CommitEvent : FolioCommitEvent
{
  new make(Diff diff, Dict? oldRec, Obj? cxInfo)
  {
    this.diff   = diff
    this.oldRec = oldRec
    this.cxInfo = cxInfo
  }

  override Diff diff
  override Dict? oldRec
  override Obj? cxInfo
}

