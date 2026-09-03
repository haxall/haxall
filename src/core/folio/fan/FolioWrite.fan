//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jul 2026  Matthew Giannini  Creation
//

using xeto

**
** FolioWrite encapsulates information about a potential commit/write.
** The is* predicates are mutually exclusive, but not exhaustive - a
** non-add commit whose rec does not exist is none of them.
**
@NoDoc const class FolioWrite
{
  ** Create a write "probe" asking generally is the rec writable.
  ** Used only by the FolioMgr write checks; the rec is always the
  ** current version resolved from a permission checked read.
  internal static FolioWrite probe(FolioRec rec) { probeRec(rec.dict) }

  ** Create a write "probe" for the given rec dict
  @NoDoc static FolioWrite probeRec(Dict rec) { make(rec) }

  ** Pending commit of the given diff. The oldRec is the current version
  ** of the rec, or null when the diff is an add or the rec does not exist.
  new makeCommit(Dict? oldRec, Diff diff)
  {
    this.oldRec = oldRec
    this.diff   = diff
  }

  ** Pending write against an existing rec which is not expressed as a Diff.
  private new make(Dict oldRec)
  {
    this.oldRec = oldRec
  }

  ** Current version of the rec being written, or null when committing
  ** an add or when the rec does not exist
  const Dict? oldRec

  ** Diff being committed, or null for writes which are not a folio rec commit
  const Diff? diff

  ** Is this a pending commit adding a new rec
  Bool isAdd() { diff != null && diff.isAdd }

  ** Is this a pending commit updating an existing rec; implies oldRec
  Bool isUpdate() { diff != null && diff.isUpdate && oldRec != null }

  ** Is this a pending commit removing an existing rec; implies oldRec
  Bool isRemove() { diff != null && diff.isRemove && oldRec != null }

  ** Is this a general writability probe with no pending diff
  Bool isProbe() { diff == null }
}

