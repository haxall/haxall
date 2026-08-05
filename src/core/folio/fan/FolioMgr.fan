//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jul 2026  Matthew Giannini  Creation
//

using haystack

**
** A Folio manager
**
@NoDoc
mixin FolioMgr
{
  ** Get the folio database
  abstract Folio db()

  ** Get the current [FolioContext] if one is installed
  FolioContext? folioCx() { FolioContext.curFolio(false) }

  ** Check current context has write permission for the given rec
  ** or raise PermissionErr; return rec
  FolioRec checkCanWrite(FolioRec rec)
  {
    db.checkWrite
    cx := folioCx
    if (cx != null && !cx.canWrite(FolioWrite.probe(rec.dict)))
      throw PermissionErr("Cannot write: ${rec.dict.id.toZinc}")
    return rec
  }

  ** Check current context has write permission for all the given recs
  ** or raise PermissionErr; return recs
  FolioRec[] checkCanWriteAll(FolioRec[] recs)
  {
    db.checkWrite
    cx := folioCx
    if (cx == null) return recs
    recs.each |rec|
    {
      if (!cx.canWrite(FolioWrite.probe(rec.dict)))
        throw PermissionErr("Cannot write: ${rec.dict.id.toZinc}")
    }
    return recs
  }
}

