//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2020  Brian Frank  Creation
//

using concurrent

**
** FolioBackup provides APIs associated with managing backups
**
const mixin FolioBackup
{
  ** List the backups currently available ordered from newest to oldest.
  abstract FolioBackupFile[] list()

  ** Kick off a backup operation in the background.  Raise exception
  ** if a backup is already running.
  abstract FolioFuture create()

  ** Backup monitor
  @NoDoc abstract Obj? monitor()

  ** Summary string of current backup operation or last backup
  @NoDoc abstract Str status()

  ** Summary of given backup file
  @NoDoc abstract Str summary(FolioBackupFile file)

}

**************************************************************************
** FolioBackupFile
**************************************************************************

**
** Handle to a backup zip file
**
const class FolioBackupFile
{
  ** Constructor
  @NoDoc new make(File file, DateTime ts) { this.file = file; this.tsRef = ts }

  ** Backup zip file
  @NoDoc const File file

  ** Timestamp the backup was started
  DateTime ts() { tsRef }
  private const DateTime tsRef

  ** Size in bytes of the backup zip file
  Int size() { file.size }

  ** Open an input stream to read the backup zip file
  InStream in() { file.in }

  ** Delete the backup file which is an unrecoverable operation
  Void delete() { file.delete }

  ** Return file name
  override Str toStr() { file.name }
}