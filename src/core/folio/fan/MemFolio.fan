//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Aug 2026  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** MemFolio is the base class for simple Folio implementations which
** store their recs in an in-memory ConcurrentMap keyed by id.  It
** implements the read hooks and common overrides; subclasses implement
** the commit pipeline and persistence.
**
@NoDoc abstract const class MemFolio : Folio
{
  ** Subclass constructor with optional pre-loaded rec map
  protected new make(FolioConfig config, ConcurrentMap map := ConcurrentMap())
    : super(config)
  {
    this.map = map
  }

  ** In-memory map of the recs keyed by id
  protected const ConcurrentMap map

  @NoDoc override Int curVer() { curVerRef.val }
  protected const AtomicInt curVerRef := AtomicInt(1)

  @NoDoc override Str flushMode
  {
    get { "fsync" }
    set { throw UnsupportedErr("flushMode") }
  }

  @NoDoc override Void flush() {}

  @NoDoc override FolioFuture doCloseAsync()
  {
    FolioFuture(CountFolioRes(0))
  }

  @NoDoc override FolioHis his() { throw UnsupportedErr() }

  @NoDoc override FolioBackup backup() { throw UnsupportedErr() }

  @NoDoc override FolioFile file() { throw UnsupportedErr() }

  @NoDoc override FolioRec? doReadRecById(Ref id)
  {
    rec := map.get(id) as Dict
    if (rec == null && id.isRel && idPrefix != null)
      rec = map.get(id.toAbs(idPrefix))
    return rec == null ? null : DictFolioRec(rec)
  }

  @NoDoc override protected Obj? doReadAllEachWhile(Filter filter, FolioReader reader)
  {
    eachWhileImpl(filter, false, reader)
  }

  @NoDoc override protected Obj? doReadTrashEachWhile(Filter filter, FolioReader reader)
  {
    eachWhileImpl(filter, true, reader)
  }

  private Obj? eachWhileImpl(Filter filter, Bool trashOnly, FolioReader reader)
  {
    map := this.map
    cx := PatherContext(|Ref id->Dict?| { map.get(id) })
    return map.eachWhile |Dict rec->Obj?|
    {
      if (!filter.matches(rec, cx)) return null
      if (rec.has("trash") != trashOnly) return null
      return reader.accept(rec)
    }
  }
}
