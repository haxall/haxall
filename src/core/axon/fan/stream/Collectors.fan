//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Aug 2019  Brian Frank  Creation
//

using xeto
using haystack

**
** Collector is used to collect a stream into an in-memory List or Grid
**
@NoDoc @Js
abstract class Collector
{
  virtual Void onStart(MStream stream) {}

  virtual Void onSignal(Signal signal) {}

  abstract Void onData(Obj? data)

  abstract Obj? onFinish()
}

**************************************************************************
** ListCollector
**************************************************************************

@NoDoc @Js
class ListCollector : Collector
{
  override Void onData(Obj? data) { list.add(data) }

  override Obj? onFinish() { list.toImmutable }

  private Obj?[] list := [,]
}

**************************************************************************
** DictCollector
**************************************************************************

@NoDoc @Js
class DictCollector
{
  new make(Dict? dict := null) { this.dict = dict }

  Dict finish()
  {
    dict != null ? dict : Etc.makeDict(map)
  }

  Void reset(Dict x)
  {
    map = null
    dict = x
  }

  Void merge(Dict m)
  {
    initMap
    m.each |v, n| { doSet(n, v) }
  }

  Void set(Str name, Obj? val)
  {
    initMap
    doSet(name, val)
  }

  private Void doSet(Str name, Obj? val)
  {
    if (val === Remove.val)
      map.remove(name)
    else
      map.set(name, val)
  }

  private Void initMap()
  {
    if (dict != null)
    {
      map = Etc.dictToMap(dict)
      dict = null
    }
    else if (map == null)
    {
      map = Str:Obj?[:]
    }
  }

  private [Str:Obj?]? map
  private Dict? dict
}

**************************************************************************
** GridCollector
**************************************************************************

@NoDoc @Js
class GridCollector : Collector
{
  override Void onStart(MStream stream)
  {
    // check if source of stream is Grid, and if so,
    // then initialize all my meta from the source
    srcStream := stream.source as GridStream
    if (srcStream != null)
    {
      src := srcStream.grid
      meta.reset(src.meta)
      src.cols.each |col|
      {
        cols.set(col.name, col.name)
        if (!col.meta.isEmpty) colMeta[col.name] = DictCollector(col.meta)
      }
    }
  }

  override Void onData(Obj? data)
  {
    // coerce every data to dict
    row := data as Dict ?: Etc.dict1x("val", data)

    // keep track of all columns seen
    row.each |v, n| { if (cols[n] == null) cols.add(n, n) }

    // add to row accumulator
    rows.add(row)
  }

  override Void onSignal(Signal signal)
  {
    switch (signal.type)
    {
      case SignalType.setMeta:     meta.reset(signal.a)
      case SignalType.addMeta:     meta.merge(signal.a)
      case SignalType.setColMeta:  toColMeta(signal.a).reset(signal.b)
      case SignalType.addColMeta:  toColMeta(signal.a).merge(signal.b)
      case SignalType.removeCols:  removeCols = addColNames(removeCols, signal.a)
      case SignalType.keepCols:    keepCols = addColNames(keepCols, signal.a)
      case SignalType.reorderCols: keepCols = addColNames(keepCols, signal.a); keepColsOrdered = true
    }
  }

  private DictCollector toColMeta(Str name)
  {
    c := colMeta[name]
    if (c == null) colMeta[name] = c = DictCollector()
    return c
  }

  private Str[] addColNames(Str[]? cur, Str[] toAdd)
  {
    if (cur == null) cur = Str[,]
    return cur.addAll(toAdd)
  }

  override Grid? onFinish()
  {
    applyRemoveCols
    applyKeepCols

    gb := GridBuilder()
    gb.setMeta(meta.finish)
    cols.each |n| { gb.addCol(n, colMeta[n]?.finish) }
    gb.capacity = rows.size
    gb.addDictRows(rows)
    return gb.toGrid
  }

  private Void applyRemoveCols()
  {
    if (removeCols == null) return
    removeCols.each |n| { cols.remove(n) }
  }

  private Void applyKeepCols()
  {
    if (keepCols == null) return
    newCols := Str:Str[:] { ordered = true }
    if (keepColsOrdered)
    {
      // reorderCols: create newCols using keepCols order
      keepCols.each |n| { if (cols[n] != null) newCols[n] = n }
    }
    else
    {
      // keepCols: create newCols using existing cols order
      keepMap := Str:Str[:].setList(keepCols)
      cols.each |n| { if (keepMap[n] != null) newCols[n] = n }
    }
    cols = newCols
  }

  DictCollector meta := DictCollector()
  private Str:DictCollector colMeta := [:]
  private Str:Str cols := [:] { ordered = true }
  private Dict[] rows := [,]
  private Str[]? removeCols
  private Str[]? keepCols
  private Bool keepColsOrdered
}

