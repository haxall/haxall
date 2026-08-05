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
  ** Convenience to create a spark write
  static FolioWrite spark(Dict rec) { FolioWrite(rec, FolioWriteType.spark) }

  ** Convenience to create a write "probe" asking generally is
  ** the rec writable.
  static FolioWrite probe(Dict rec) { FolioWrite(rec, FolioWriteType.rec) }

  ** Pending commit of the given diff. The oldRec is the current version
  ** of the rec, or null when the diff is an add.
  new makeCommit(Dict? oldRec, Diff diff)
  {
    this.oldRec = oldRec
    this.diff   = diff
    this.type   = FolioWriteType.rec
  }

  ** Pending write against an existing rec which is not expressed as a Diff.
  ** The type tells us more about what kind of write is being attempted.
  private new make(Dict oldRec, FolioWriteType type)
  {
    this.oldRec = oldRec
    this.type   = type
  }

  ** Current version of the rec being written, or null when committing an add
  const Dict? oldRec

  ** Diff being committed, or null for writes which are not a folio rec commit.
  const Diff? diff

  ** Type of write being performed
  const FolioWriteType type
}

** The type of write being done by FolioWrite.
@NoDoc enum class FolioWriteType
{
  rec,
  spark
}

