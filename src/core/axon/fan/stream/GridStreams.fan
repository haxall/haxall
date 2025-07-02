//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2019  Brian Frank  Creation
//

using xeto
using haystack

@Js
internal class GridStream : SourceStream
{
  new make(Grid grid) { this.grid = grid }

  override Bool isGridStage() { true }

  override Str funcName() { "stream" }

  override Obj?[] funcArgs() { [grid] }

  override Void onStart(Signal sig)
  {
    grid.eachWhile |row|
    {
      submit(row)
      return isComplete ? "break" : null
    }
  }

  internal Grid grid
}

**************************************************************************
** GridColStream
**************************************************************************

@Js
internal class GridColStream : SourceStream
{
  new make(Grid grid, Col col) { this.grid = grid; this.col = col }

  override Str funcName() { "streamCol" }

  override Obj?[] funcArgs() { [grid, col.name] }

  override Void onStart(Signal sig)
  {
    grid.eachWhile |row|
    {
      submit(row.val(col))
      return isComplete ? "break" : null
    }
  }

  internal Grid grid
  internal Col col
}

**************************************************************************
** GridTransformStream
**************************************************************************

@Js
internal abstract class GridTransformStream : PassThruStream
{
  new make(MStream prev) : super(prev) {}

  override final Bool isGridStage() { true }
}

**************************************************************************
** SetMetaStream
**************************************************************************

@Js
internal class SetMetaStream : GridTransformStream
{
  new make(MStream prev, Dict meta) : super(prev) { this.meta = meta }

  override Str funcName() { "setMeta" }

  override Obj?[] funcArgs() { [meta] }

  override Void onStart(Signal s) { signal(Signal(SignalType.setMeta, meta)) }

  private const Dict meta
}

**************************************************************************
** AddMetaStream
**************************************************************************

@Js
internal class AddMetaStream : GridTransformStream
{
  new make(MStream prev, Dict meta) : super(prev) { this.meta = meta }

  override Str funcName() { "addMeta" }

  override Obj?[] funcArgs() { [meta] }

  override Void onStart(Signal s) { signal(Signal(SignalType.addMeta, meta)) }

  private const Dict meta
}

**************************************************************************
** SetColMetaStream
**************************************************************************

@Js
internal class SetColMetaStream : GridTransformStream
{
  new make(MStream prev, Str name, Dict meta) : super(prev) { this.name = name; this.meta = meta }

  override Str funcName() { "setColMeta" }

  override Obj?[] funcArgs() { [name, meta] }

  override Void onStart(Signal s) { signal(Signal(SignalType.setColMeta, name, meta)) }

  private const Str name
  private const Dict meta
}

**************************************************************************
** AddColMetaStream
**************************************************************************

@Js
internal class AddColMetaStream : GridTransformStream
{
  new make(MStream prev, Str name, Dict meta) : super(prev) { this.name = name; this.meta = meta }

  override Str funcName() { "addColMeta" }

  override Obj?[] funcArgs() { [name, meta] }

  override Void onStart(Signal s) { signal(Signal(SignalType.addColMeta, name, meta)) }

  private const Str name
  private const Dict meta
}

**************************************************************************
** ReorderColsStream
**************************************************************************

@Js
internal class ReorderColsStream : GridTransformStream
{
  new make(MStream prev, Str[] cols) : super(prev) { this.cols = cols }

  override Str funcName() { "reorderCols" }

  override Obj?[] funcArgs() { [cols] }

  override Void onStart(Signal s) { signal(Signal(SignalType.reorderCols, cols)) }

  private Str[] cols
}

**************************************************************************
** KeepColsStream
**************************************************************************

@Js
internal class KeepColsStream : GridTransformStream
{
  new make(MStream prev, Str[] cols) : super(prev) { this.cols = cols }

  override Str funcName() { "keepCols" }

  override Obj?[] funcArgs() { [cols] }

  override Void onStart(Signal s) { signal(Signal(SignalType.keepCols, cols)) }

  private const Str[] cols
}

**************************************************************************
** RemoveColsStream
**************************************************************************

@Js
internal class RemoveColsStream : GridTransformStream
{
  new make(MStream prev, Str[] cols) : super(prev) { this.cols = cols }

  override Str funcName() { "removeCols" }

  override Obj?[] funcArgs() { [cols] }

  override Void onStart(Signal s) { signal(Signal(SignalType.removeCols, cols)) }

  private Str[] cols
}

