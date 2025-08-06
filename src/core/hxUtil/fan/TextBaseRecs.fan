//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    6 Aug 2025  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** TextBaseRecs uses a TextBase file to manage a simple in-memory
** cache of dict records keyed by ids and stored to disk as trio file.
**
const class TextBaseRecs
{
  ** Constructor
  new make(TextBase tb, Str filename)
  {
    this.tb = tb
    this.filename = filename

    // load
    file := tb.read(filename, false)
    if (file != null) TrioReader(file.in).readAllDicts.each |rec|
    {
      byId[rec.id] = rec
    }
  }

  ** Text base used to read/write
  const TextBase tb

  ** Filename in text base
  const Str filename

  ** Lookup record by id
  Dict? readById(Ref id, Bool checked := true)
  {
    rec := byId.get(id)
    if (rec != null) return rec
    if (checked) throw UnknownRecErr(id.toStr)
    return null
  }

  ** Read all recs by filter
  Dict[] readAllList(Filter filter)
  {
    acc := Dict[,]
    byId.each |rec| { if (filter.matches(rec)) acc.add(rec) }
    return acc
  }

  ** Update record with given changes (or create it not found)
  ** We do always generate a 'mod' tag, but do not check it.
  Dict update(Ref id, Dict changes)
  {
    modify |->Dict|
    {
      acc := Str:Obj[:]
      old := byId.get(id) as Dict
      if (old == null) acc["id"] = id
      else old.each |v, n| { acc[n] = v }
      changes.each |v, n|
      {
        if (n == "id" || n == "mod") throw ArgErr("Invalid change tag: $n")
        if (v === Remove.val) acc.remove(n)
        else acc[n] = v
      }
      acc["mod"] = DateTime.nowUtc
      rec :=  Etc.dictFromMap(acc)

      dis := rec["dis"] as Str
      if (dis != null) rec.id.disVal = dis

      byId.set(id, rec)
      return rec
    }
  }

  ** Remove record by id
  Void remove(Ref id)
  {
    modify |->|
    {
      byId.remove(id)
    }
  }

  ** Update in-memory and disk copy holding lock
  private Obj? modify(|->Obj?| cb)
  {
    lock.lock
    try
    {
      // callback
      res := cb()

      // rewrite trio file
      buf := StrBuf()
      TrioWriter(buf.out).writeAllDicts(byId.vals(Dict#))

      // update disk file
      tb.write(filename, buf.toStr)

      return res
    }
    finally lock.unlock
  }

  private const ConcurrentMap byId := ConcurrentMap()
  private const Lock lock := Lock.makeReentrant
}

