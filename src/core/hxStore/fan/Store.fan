//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2016  Brian Frank  Creation
//

**
** Database storage engine as file system of blobs.
**
native const final class Store
{
  ** Open the database for the given directory
  static Store open(File dir, StoreConfig? config := null)

  ** Store level fixed meta data
  StoreMeta meta()

  ** Directory used to store the database files
  File dir()

  ** Database's current journaling version number which is
  ** incremented for every modification to the database.
  Int ver()

  ** Return number of active blobs in the database.
  Int size()

  ** LockFile to ensure exclusive access
  LockFile lockFile()

  ** Non-zero if one or more GC freezes are in effect
  Int gcFreezeCount()

  ** Lookup an active blob by its handle.  If not found or
  ** deleted then raise UnknownBlobErr or return null.
  Blob? blob(Int handle, Bool checked := true)

  ** Iterate all the active blobs in the database.
  Void each(|Blob| f)

  ** Create a new blob in the database.  A new
  ** handle is auto-generated.
  Blob create(Buf meta, Buf data)

  ** Configure disk flush method:
  **   - "fsync": fsync after every write - slow but safest (default)
  **   - "nosync": do nothing after every write - fast but no safety
  native Str flushMode

  ** Number of unflushed files when flushMode is "nosync"
  Int unflushedCount()

  ** Flush any dirty files to disk using fsync
  Void flush()

  ** Close database
  Void close()

  ** Get/Set the store readonly mode.
  native Bool ro

  ** Callback when any write to file system throws an I/O exception
  native |Err|? onWriteErr

  ** Whitebox testing hook
  internal Bool isUsed(Int fileId, Int pageId)

  ** Create a full backup of the database to the given zip file.  The backup
  ** is run on on a dedicated background thread and only one backup may be active.
  ** During the backup the database is fully read/write accessible.  Return
  ** an instance which may be used to track progess.  Pass null for file to
  ** query the current backup if one is running.
  **
  ** Options
  **   - pathPrefix: directory path within zip file as Uri or Str
  **   - testDelay: whitebox testing hook to insert delay as Duration
  **   - futureResult: object used to complete future
  BackupMonitor? backup(File? file := null, [Str:Obj]? opts := null)

  ** Total number of page files
  @NoDoc Int pageFileSize()

  ** Page file distribution formatted as "pageSize,numFiles,numBlobs".
  @NoDoc Str[] pageFileDistribution()

  ** Debug dump for files
  @NoDoc Void debugFiles(OutStream out)

  ** White-box testing flag
  @NoDoc native Bool testDiskFull

  ** Return number of deleted blobs not yet reclaimed
  @NoDoc Int deletedSize()

  ** Lookup a deleted blob by its handle (top four bytes ignored)
  @NoDoc Blob? deletedBlob(Int handle, Bool checked := true)

  ** Iterate all the deleted blobs in the database.
  @NoDoc Void deletedEach(|Blob| f)

}

**************************************************************************
** StoreConfig
**************************************************************************

**
** Store open options
**
const class StoreConfig
{
  ** It-block constructor
  new make(|This|? f := null)
  {
    if (f != null) f(this)
    if (hisPageSize < 1hr) throw Err("Invalid hisPageSize: $hisPageSize < 1hr")
    if (hisPageSize > 100day) throw Err("Invalid hisPageSize: $hisPageSize > 100day")
    if (hisPageSize.ticks.mod(1hr.ticks) != 0) throw Err("Invalid hisPageSize: must be hours");
  }

  ** History paging window size (create only)
  const Duration hisPageSize := 10day
}

**************************************************************************
** StoreMeta
**************************************************************************

**
** Fixed meta data stored in index header
**
native const final class StoreMeta
{
  ** Max number of bytes in blob meta
  Int blobMetaMax()

  ** Max number of bytes in blob data
  Int blobDataMax()

  ** Number of ticks in each history page
  Duration hisPageSize()
}

**************************************************************************
** JavaTestBridge (needs to be fan/ for test stripping)
**************************************************************************

class JavaTestBridge
{
  new make(Test t) { test = t }
  Void verify(Bool b) { test.verify(b) }
  Test test
}


