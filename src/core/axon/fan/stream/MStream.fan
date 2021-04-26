//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2019  Brian Frank  Creation
//

using haystack

**
** MStream is base class for Stream implementations
**
@NoDoc @Js
abstract class MStream
{
  ** Constructor
  new make(MStream? prev)
  {
    if (prev == null)
    {
      if (!isSource) throw Err("Missing stream source: $typeof")
      this.cx = AxonContext.curAxon
    }
    else
    {
      if (prev.isTerminal) throw Err("Stream is terminated by: $prev.typeof")
      this.cx = prev.cx
      this.prev = prev
      prev.next = this
    }
  }

//////////////////////////////////////////////////////////////////////////
// Stream
//////////////////////////////////////////////////////////////////////////

  ** Head of the stream
  MStream source()
  {
    x := this; while (x.prev != null) x = x.prev; return x
  }

  ** Tail of the stream
  MStream terminal()
  {
    x := this; while (x.next != null) x = x.next; return x
  }

  ** Previous step in stream
  MStream? prev { private set }

  ** Next step in the stream
  MStream? next { private set }

  ** Walk this stream from this step back to the source step
  Void walk(|MStream stage| f)
  {
    for (MStream? x := this; x != null; x = x.prev) f(x)
  }

  ** Is this a source stream step
  abstract Bool isSource()

  ** Is this a terminal stream step
  abstract Bool isTerminal()

  ** Is this a stream which should infer grid result
  virtual Bool isGridStage() { false }

//////////////////////////////////////////////////////////////////////////
// Pipeline
//////////////////////////////////////////////////////////////////////////

  ** Send start signal along the entire stream from source to sink
  Void signalStart()
  {
    source.signal(Signal.start)
  }

  ** Send complete signal along the entire stream from source to sink
  Void signalComplete()
  {
    source.signal(Signal.complete)
  }

  ** Send signal from this step and downstream all the way to terminal step
  Void signal(Signal signal)
  {
    for (MStream? x := this; x != null; x = x.next) x.doSignal(signal)
  }

  ** Submit data item downstream
  Void submit(Obj? data)
  {
    if (complete) throw Err("submit to complete stream")
    if (next != null) next.onData(data)
  }

  ** Submit list of data items downstream
  Void submitAll(Obj?[] dataList)
  {
    dataList.eachWhile |data|
    {
      submit(data)
      return complete ? "break" : null
    }
  }

  ** Has this stream completed (either succesfully or with error)
  Bool isComplete() { complete }

//////////////////////////////////////////////////////////////////////////
// Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Data item callback
  virtual Void onData(Obj? data) {}

  ** Built-in signal handling before routing to onSignal
  private Void doSignal(Signal sig)
  {
    if (sig.isComplete) complete = true
    switch (sig.type)
    {
      case SignalType.start:    onStart(sig)
      case SignalType.complete: onComplete(sig)
    }
    onSignal(sig)
  }

  ** Start signal callback
  virtual Void onStart(Signal sig) {}

  ** Complete signal callback
  virtual Void onComplete(Signal sig) {}

  ** Signal callback called independently of onStart, onComplete, etc
  virtual Void onSignal(Signal sig) {}

//////////////////////////////////////////////////////////////////////////
// Encoding
//////////////////////////////////////////////////////////////////////////

  ** Function name to encode
  abstract Str funcName()

  ** Function args to encode (does not include prev stream)
  virtual Obj?[] funcArgs() { Obj#.emptyList }

  ** Encode this stage and everything upstream into a Grid.
  Grid encode()
  {
    // iterate back to source and build args list
    argsPerStep := List[,]
    maxNumArgs := 0
    x := this
    while (true)
    {
      args := x.funcArgs
      maxNumArgs = maxNumArgs.max(args.size)
      argsPerStep.add(args)
      if (x.prev == null) break
      x = x.prev
    }

    // init grid builder
    gb := GridBuilder()
    gb.addCol("name")
    maxNumArgs.times |i| { gb.addCol("arg$i") }

    // add row from source back to me
    n := argsPerStep.size-1
    while (true)
    {
      row := Obj?[,]
      row.size = gb.numCols
      row.set(0, x.funcName)
      args := argsPerStep[n--]
      args.each |arg, i| { row.set(i+1, encodeArg(arg)) }
      gb.addRow(row)
      if (x === this) break
      x = x.next
    }
    return gb.toGrid
  }

  private static Obj? encodeArg(Obj? val)
  {
    if (val is Fn)     return XStr("Fn", val.toStr)
    if (val is Filter) return XStr("Filter", val.toStr)
    if (val is Range)  return XStr("Range", val.toStr)
    return val
  }

  ** Decode a stream from grid
  static MStream decode(AxonContext cx, Grid grid)
  {
    if (grid.isEmpty) throw Err("Grid is empty")
    nameCol  := grid.cols[0]
    argsCols := grid.cols[1..-1]
    MStream? stream := null
    grid.each |row|
    {
      func := cx.findTop(row.val(nameCol))
      args := Obj?[,]
      args.capacity = 1 + argsCols.size
      if (stream != null) args.add(stream)
      argsCols.each |argCol| { args.add(decodeArg(cx, row.val(argCol))) }
      stream = func.call(cx, args)
    }
    return stream
  }

  private static Obj? decodeArg(AxonContext cx, Obj? val)
  {
    x := val as XStr
    if (x == null) return val
    switch (x.type)
    {
      case "Fn":     return cx.evalToFunc(x.val)
      case "Filter": return FilterExpr(Filter.fromStr(x.val))
      case "Range":  return ObjRange.fromIntRange(Range.fromStr(x.val))
      default:       return val
    }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  AxonContext cx { private set }
  private Bool complete
}