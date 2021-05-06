//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2016  Brian Frank  Creation
//

**
** Blob is a "mini-file" in a Store:
**   - identified by an auto-generated 64-bit handle
**   - BlobMeta provides up tp 32 bytes cached in RAM for indexing
**   - data page up to 1MB stored on disk
**
native const final class Blob
{
  ** Database associated with this blob
  Store store()

  ** Unique identifier within store
  Int handle()

  ** Binary meta-data cached in RAM
  BlobMeta meta()

  ** This blobs's journaling version number
  Int ver()

  ** Size of the data page in bytes or -1 if deleted
  Int size()

  ** Return if this blob is not deleted
  Bool isActive()

  ** Has this blob been deleted.  Deleted blobs remain active in memory
  ** and for lookup until their index slot if reclaimed by create.
  Bool isDeleted()

  ** Data page fileId
  internal Int fileId()

  ** Data page pageId
  internal Int pageId()

  ** Return fileId:pageId for debug
  Str locToStr()

  ** Read the data page into the buffer provided.
  ** Return the same buffer instance.
  Buf read(Buf buf)

  ** Write meta and/or data to the disk.  If meta is non-null, then
  ** it is updated in RAM and written to disk.  If data is non-null
  ** then this blob's data page is rewritten.  The journaling version
  ** is automatically incremented.  If expectedVer is passed then
  ** raise a ConcurrentWriteErr if the current version does not match
  ** the expected version while holding blob lock.
  Void write(Buf? meta, Buf? data, Int expectedVer := -1)

  ** Append the buf to the blob's data.  If meta is non-null, then
  ** it is updated in RAM and written to disk.  The journaling version
  ** is automatically incremented.
  Void append(Buf? meta, Buf data)

  ** Delete this blob from the database.  This does not update
  ** the store's journaling version; however this blob's index
  ** will be reused with a unique handle on next create.
  Void delete()

  ** Application stash - must be an immutable object
  native Obj? stash

  ** Human friendly representation of handle
  static Str handleToStr(Int h)

  ** Parse human friendly representation of handle
  static Int handleFromStr(Str h)
}

