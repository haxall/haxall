//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2016  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hxStore

**
** DebugMgr
**
@NoDoc const class DebugMgr : HxFolioMgr
{

  new make(HxFolio folio) : super(folio) {}

  Grid recBlobs(Ref[] ids)
  {
    gb := GridBuilder()
    gb.addCol("id").addCol("blobHandle").addCol("blobSize")
    ids.each |id|
    {
      rec := folio.index.rec(id, false)
      if (rec == null) return
      blob := rec.blob
      gb.addRow([
        id,
        blob.toStr,
        Number(blob.size, Number.byte)
      ])
    }
    return gb.toGrid
  }

  Void dump(OutStream out)
  {
    out.printLine("--- Summary ---")
    folio.stats.debugSummary.each |row|
    {
      out.print(row["dis"]).print(": ").printLine(row["val"])
    }

    out.printLine
    out.printLine("--- Page Size Distribution ---")
    out.printLine("pageSize   numFiles       numBlobs")
    folio.store.blobs.pageFileDistribution.each |line|
    {
      toks     := line.split(',')
      pageSize := toks[0].toInt.toLocale("B").padl(8)
      numFiles := toks[1].toInt.toLocale.padl(10)
      numBlobs := toks[2].toInt.toLocale.padl(14)
      out.print(pageSize).print(" ").print(numFiles).print(" ").printLine(numBlobs)
    }

    out.printLine
    out.printLine("--- ActorPool ---")
    folio.config.pool->dump(out)

    out.printLine
    out.printLine("--- IndexMgr ---")
    folio.index.debugDump(out)

    out.printLine
    out.printLine("--- StoreMgr ---")
    folio.store.debugDump(out)
  }
}