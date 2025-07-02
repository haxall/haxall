//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2019  Brian Frank  Creation
//

using xeto
using haystack

**
** TransformStream is base class for 1-to-1 streams
**
@NoDoc @Js
abstract class TransformStream : MStream
{
  new make(MStream prev) : super(prev) {}

  override final Bool isSource() { false }

  override final Bool isTerminal() { false }
}

**************************************************************************
** PassThruStream
**************************************************************************

@NoDoc @Js
abstract class PassThruStream : TransformStream
{
  new make(MStream prev) : super(prev) {}

  override Void onData(Obj? data) { submit(data) }
}

**************************************************************************
** MapStream
**************************************************************************

@Js
internal class MapStream : TransformStream
{
  new make(MStream prev, Fn func) : super(prev) { this.func = func }

  override Str funcName() { "map" }

  override Obj?[] funcArgs() { [func] }

  override Void onData(Obj? data) { submit(func.call(cx, [data])) }

  private Fn func
}

**************************************************************************
** LimitStream
**************************************************************************

@Js
internal class LimitStream : TransformStream
{
  new make(MStream prev, Int limit) : super(prev) { this.limit = limit }

  override Str funcName() { "limit" }

  override Obj?[] funcArgs() { [Number(limit)] }

  override Void onData(Obj? data)
  {
    count++
    if (count > limit)
      signalComplete
    else
      submit(data)
  }

  private const Int limit
  private Int count
}


**************************************************************************
** SkipStream
**************************************************************************

@Js
internal class SkipStream : TransformStream
{
  new make(MStream prev, Int count) : super(prev) { this.count = count }

  override Str funcName() { "skip" }

  override Obj?[] funcArgs() { [Number(count)] }

  override Void onData(Obj? data)
  {
    if (seen >= count) submit(data)
    seen++
  }

  private Int count
  private Int seen
}


**************************************************************************
** FlatMapStream
**************************************************************************

@Js
internal class FlatMapStream : TransformStream
{
  new make(MStream prev, Fn func) : super(prev) { this.func = func }

  override Str funcName() { "flatMap" }

  override Obj?[] funcArgs() { [func] }

  override Void onData(Obj? data)
  {
    r := func.call(cx, [data])
    if (r == null) return
    if (r is Grid) r = ((Grid)r).toRows
    list := r as List ?: throw Err("flatMap must return list")
    submitAll(list)
  }

  private const Fn func
}

**************************************************************************
** FindAllStream
**************************************************************************

@Js
internal class FindAllStream : TransformStream
{
  new make(MStream prev, Fn func) : super(prev) { this.func = func }

  override Str funcName() { "findAll" }

  override Obj?[] funcArgs() { [func] }

  override Void onData(Obj? data) { if (func.call(cx, [data])) submit(data) }

  private const Fn func
}

**************************************************************************
** FilterStream
**************************************************************************

@Js
internal class FilterStream : TransformStream
{
  new make(MStream prev, Filter filter) : super(prev) { this.filter = filter }

  override Str funcName() { "filter" }

  override Obj?[] funcArgs() { [filter] }

  override Void onData(Obj? data)
  {
    if (data == null) return
    dict := data as Dict ?: throw Err("filter data not Dict [$data.typeof]")
    if (filter.matches(dict, cx)) submit(data)
  }

  private const Filter filter
}

