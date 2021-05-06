//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jun 2016  Brian Frank  Creation
//

using concurrent

**
** Monitor progress of a backup operation
**
native const final class BackupMonitor
{
  ** Associated store
  Store store()

  ** Zip file we are backing up to
  File file()

  ** Percent progress from 0% to 100%
  Int progress()

  ** Time operation was started
  DateTime startTime()

  ** End of operation or null if still going
  DateTime? endTime()

  ** Future to monitor completion of this backup
  Future future()

  ** True when backup completes either with success or failure
  Bool isComplete()

  ** Non-null if completed with an error condition
  Err? err()

  ** Register a callback for when backup completes either
  ** successfully or on error
  Void onComplete(|This| f)
}

