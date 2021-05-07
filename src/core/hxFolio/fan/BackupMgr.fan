//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2016  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hxStore

**
** BackupMgr
**
@NoDoc
const class BackupMgr : HxFolioMgr, FolioBackup
{
  new make(HxFolio folio) : super(folio)
  {
    this.dir  = folio.dir + `../backup/`
  }

  override FolioBackupFile[] list()
  {
    acc := FolioBackupFile[,]
    dir.list.each |f|
    {
      if (f.isDir || f.ext != "zip") return
      try
      {
        // format is {proj-name}-yymmdd-hhmmss.zip
        //          neg indices: 321098-654321
        s := f.basename
        date := Date(2000+s[-13..-12].toInt, Month.vals[s[-11..-10].toInt-1], s[-9..-8].toInt)
        time := Time(s[-6..-5].toInt, s[-4..-3].toInt, s[-2..-1].toInt)
        ts := date.toDateTime(time)
        acc.add(FolioBackupFile(f, ts))
      }
      catch {}
    }
    return acc.sortr |a, b| { a.ts <=> b.ts }
  }

  override BackupMonitor? monitor() { curBackup }

  override FolioFuture create()
  {
    ts := DateTime.now(null).toLocale("YYMMDD-hhmmss")
    file := dir + `${folio.name}-${ts}.zip`
    if (file.exists) throw IOErr("Backup file already exists: $file")

    log.info("Backup $file.name.toCode ...")
    bm := kickoff(file, ["pathPrefix":`$file.basename/db/`, "futureResult":BackupFolioRes()])
    lastRef.val = bm

    bm.onComplete |x|
    {
      dur := x.endTime - x.startTime
      if (x.err == null)
        log.info("Backup completed [" + x.file.size.toLocale("B") + ", $dur.toLocale]")
      else
        log.err("Backup failed", x.err)
    }

    return FolioFuture.makeAsync(bm.future)
  }

  override Str status()
  {
    // check if backup is in progress
    bm := curBackup
    if (bm != null) return "Backup in progress [${bm.progress}%]"

    // check if last backup had an error
    bm = lastRef.val
    if (bm != null && bm.err != null)
      return "Backup error: $bm.err.toStr"

    // return last file we have
    last := list.first
    if (last != null)
    {
      ts := last.ts
      when := ts.date == Date.today ? "today at $ts.time.toLocale" : ts.date.toLocale
      return "Last backup was $when"
    }

    return "No backups"
  }

  override Str summary(FolioBackupFile b)
  {
    // check if this is backup file in progress
    bm := curBackup
    if (bm != null && bm.file.name == b.file.name)
      return "Backup in progress [${bm.progress}%]"

    // create "X ago" message
    return Etc.tsToDis(b.ts)
  }

  private BackupMonitor? curBackup()
  {
    folio.store.blobs.backup(null, null)
  }

  private BackupMonitor? kickoff(File zip, [Str:Obj]? opts := null)
  {
    folio.store.blobs.backup(zip, opts)
  }

  const File dir
  const AtomicRef lastRef := AtomicRef()

}