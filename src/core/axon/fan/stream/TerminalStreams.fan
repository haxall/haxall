//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2019  Brian Frank  Creation
//

using haystack

**
** TerminalStream is base class for functions which terminate the stream
**
@NoDoc @Js
abstract class TerminalStream : MStream
{
  new make(MStream prev) : super(prev) {}

  override final Bool isSource() { false }

  override final Bool isTerminal() { true }

  Obj? run()
  {
    onPreRun
    signalStart
    return onRun
  }

  virtual Void onPreRun() {}

  abstract Obj? onRun()
}

**************************************************************************
** CollectStream
**************************************************************************

@Js
internal class CollectStream : TerminalStream
{
  new make(MStream prev, Fn? to) : super(prev) { this.to = to }

  override Str funcName() { "collect" }

  override Obj?[] funcArgs() { to == null ? super.funcArgs  : [to] }

  override Void onPreRun()
  {
    collector = initCollector
    collector.onStart(this)
  }

  override Void onSignal(Signal signal)
  {
    collector.onSignal(signal)
  }

  private Collector initCollector()
  {
    if (to == null) return inferToGrid ? GridCollector() : ListCollector()

    switch (to.name)
    {
      case "toGrid": return GridCollector()
      case "toList": return ListCollector()
      default:       throw Err("Unsupported collect func: $to.name")
    }
  }

  private Bool inferToGrid()
  {
    // walk stream looking for any grid steps
    hasGridStage := false
    walk |s| { hasGridStage = hasGridStage || s.isGridStage }
    return hasGridStage
  }

  override Void onData(Obj? data) { collector.onData(data) }

  override Obj? onRun() { collector.onFinish }

  private Collector? collector
  private Fn? to
}

**************************************************************************
** EachStream
**************************************************************************

@Js
internal class EachStream : TerminalStream
{
  new make(MStream prev, Fn func) : super(prev) { this.func = func }

  override Str funcName() { "each" }

  override Obj?[] funcArgs() { [func] }

  override Void onData(Obj? data) { func.call(cx, [data]) }

  override Obj? onRun() { null }

  private const Fn func
}

**************************************************************************
** EachWhileStream
**************************************************************************

@Js
internal class EachWhileStream : TerminalStream
{
  new make(MStream prev, Fn func) : super(prev) { this.func = func }

  override Str funcName() { "eachWhile" }

  override Obj?[] funcArgs() { [func] }

  override Void onData(Obj? data)
  {
    result = func.call(cx, [data])
    if (result != null) signalComplete
  }

  override Obj? onRun() { result }

  private const Fn func
  private Obj? result
}

**************************************************************************
** FindStream
**************************************************************************

@Js
internal class FindStream : TerminalStream
{
  new make(MStream prev, Fn func) : super(prev) { this.func = func }

  override Str funcName() { "find" }

  override Obj?[] funcArgs() { [func] }

  override Void onData(Obj? data)
  {
    if (func.call(cx, [data]))
    {
      result = data
      signalComplete
    }
  }

  override Obj? onRun() { result }

  private const Fn func
  private Obj? result
}

**************************************************************************
** ReduceStream
**************************************************************************

@Js
internal class ReduceStream : TerminalStream
{
  new make(MStream prev, Obj? init, Fn func) : super(prev) { this.acc = init; this.func = func }

  override Str funcName() { "reduce" }

  override Void onData(Obj? data)
  {
    acc = func.call(cx, args.set(0, acc).set(1, data))
  }

  override Obj? onRun()
  {
    acc
  }

  private const Fn func
  private Obj?[] args := [null, null]
  private Obj? acc
}

**************************************************************************
** FoldStream
**************************************************************************

@Js
internal class FoldStream : TerminalStream
{
  new make(MStream prev, Fn func) : super(prev) { this.func = func }

  override Str funcName() { "fold" }

  override Void onData(Obj? data)
  {
    acc = func.call(cx, args.set(0, data).set(1, acc))
    if (acc == NA.val) signalComplete
  }

  override Void onPreRun()
  {
    acc = func.call(cx, args.set(0, CoreLib.foldStart).set(1, acc))
  }

  override Obj? onRun()
  {
    func.call(cx, args.set(0, CoreLib.foldEnd).set(1, acc))
  }

  private const Fn func
  private Obj?[] args := [null, null]
  private Obj? acc
}

**************************************************************************
** FirstStream
**************************************************************************

@Js
internal class FirstStream : TerminalStream
{
  new make(MStream prev) : super(prev) {}

  override Str funcName() { "first" }

  override Obj? onRun() { result }

  override Void onData(Obj? data)
  {
    result = data
    signalComplete
  }

  Obj? result
}

**************************************************************************
** LastStream
**************************************************************************

@Js
internal class LastStream : TerminalStream
{
  new make(MStream prev) : super(prev) {}

  override Str funcName() { "last" }

  override Obj? onRun() { result }

  override Void onData(Obj? data) { result = data }

  Obj? result
}

**************************************************************************
** AnyStream
**************************************************************************

@Js
internal class AnyStream : TerminalStream
{
  new make(MStream prev, Fn func) : super(prev) { this.func = func }

  override Str funcName() { "any" }

  override Obj?[] funcArgs() { [func] }

  override Void onData(Obj? data)
  {
    if (func.call(cx, [data]))
    {
      result = true
      signalComplete
    }
  }

  override Obj? onRun() { result }

  private const Fn func
  private Bool result := false
}

**************************************************************************
** AllStream
**************************************************************************

@Js
internal class AllStream : TerminalStream
{
  new make(MStream prev, Fn func) : super(prev) { this.func = func }

  override Str funcName() { "all" }

  override Obj?[] funcArgs() { [func] }

  override Void onData(Obj? data)
  {
    if (!func.call(cx, [data]))
    {
      result = false
      signalComplete
    }
  }

  override Obj? onRun() { result }

  private const Fn func
  private Bool result := true
}


