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
**
@NoDoc const class FolioWrite
{
  ** Create a write "probe" asking generally is the rec writable.
  ** Used only by the FolioMgr write checks; the rec is always the
  ** current version resolved from a permission checked read.
  internal static FolioWrite probe(FolioRec rec) { make(rec.dict) }

  ** Pending commit of the given diff. The oldRec is the current version
  ** of the rec, or null when the diff is an add.
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

  ** Current version of the rec being written, or null when committing an add
  const Dict? oldRec

  ** Diff being committed, or null for writes which are not a folio rec commit
  const Diff? diff
}

