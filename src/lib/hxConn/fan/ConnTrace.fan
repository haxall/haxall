//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Dec 2021  Brian Frank  Creation, hanging out in Cape Charles
//

using concurrent
using haystack
using hx
using hxUtil

**
** ConnTrace provides a debug trace for each connector.
** Trace messages are stored in RAM using a circular buffer.
**
const class ConnTrace : Actor
{
  ** Constructor
  internal new make(ActorPool pool) : super(pool)
  {
    this.actor = ConnTraceActor(this, pool)
  }

  ** Max number of trace messages to store in RAM
  Int max() { 500 }

  ** Is tracing currently enabled for the connector
  Bool isEnabled() { enabled.val }

  ** Enable tracing the connector
  Void enable()
  {
    if (enabled.compareAndSet(false, true))
      actor.send(HxMsg("enable")).get(null)
  }

  ** Disable tracing for the connector
  Void disable()
  {
    if (enabled.compareAndSet(true, false))
      actor.send(HxMsg("disable")).get(null)
  }

  ** Clear the trace log
  Void clear()
  {
    actor.send(HxMsg("clear"))
  }

  ** Get the current trace messages or empty list if not enabled.
  ** Messages are ordered from oldest to newest.
  ConnTraceMsg[] read()
  {
    readSince(null)
  }

  ** Read all trace messages since the given timestamp.  If the
  ** timestamp is null, then read all messages in the buffer.
  ** Messages are ordered from oldest to newest.
  ConnTraceMsg[] readSince(DateTime? since)
  {
    ((Unsafe)actor.send(HxMsg("read", since)).get).val
  }

  ** Write a trace message
  Void write(Str type, Str msg, Obj? arg := null)
  {
    if (isEnabled)
    {
      if (arg != null && !arg.isImmutable) throw NotImmutableErr("Trace arg not immutable: $arg.typeof")
      actor.send(ConnTraceMsg(type, msg, arg))
    }
  }

  ** Trace a phase message
  Void phase(Str msg, Obj? arg := null)
  {
    write("phase", msg, arg)
  }

  ** Trace a dispatch message
  Void dispatch(HxMsg msg)
  {
    write("dispatch", msg.id, msg)
  }

  ** Trace a poll message
  Void poll(Str msg, Obj? arg := null)
  {
    write("poll", msg, arg)
  }

  ** Trace a protocol specific request message.
  ** The arg must be a Str or Buf.  If arg is a Buf then you must
  ** call 'toImmutable' on it first to ensure backing array is not cleared.
  Void req(Str msg, Obj arg)
  {
    write("req", msg, arg)
  }

  ** Trace a protocol specific response message.
  ** The arg must be a Str or Buf.  If arg is a Buf then you must
  ** call 'toImmutable' on it first to ensure backing array is not cleared.
  Void res(Str msg, Obj arg)
  {
    write("res", msg, arg)
  }

  ** Trace a protocol specific unsolicited event message.
  ** The arg must be a Str or Buf.  If arg is a Buf then you must
  ** call 'toImmutable' on it first to ensure backing array is not cleared.
  Void event(Str msg, Obj arg)
  {
    write("event", msg, arg)
  }

  ** Expose the trace as a standard system log.  Messages sent to
  ** the log instance are traced as follows:
  **   - if message starts with ">" it is logged as "req" type
  **   - if message starts with "<" it is logged as "res" type
  **   - if message starts with "^" it is logged as "event" type
  **   - otherwise it is logged as "log" type
  **
  ** When logging as a request/response the 2nd line is used as summary
  ** with the expectation that log format is patterned as follows:
  **    < message-id
  **    Summary line
  **    ... more details ...
  Log asLog() { log }
  internal const Log log := ConnTraceLog(this)

  ** Actor which implements the trace APIs
  private const ConnTraceActor actor

  ** Enabled flag
  private const AtomicBool enabled := AtomicBool()
}

**************************************************************************
** ConnTraceItem
**************************************************************************

**
** ConnTraceMsg models one timestamped trace message
**
const final class ConnTraceMsg
{
  ** Convert list of trace messages to a grid
  static Grid toGrid(ConnTraceMsg[] list, Obj? meta := null)
  {
    gb := GridBuilder()
    gb.setMeta(meta)
    gb.addCol("ts", Etc.makeDict1("format", "hh:mm:ss.fff"))
      .addCol("connTraceType", Etc.makeDict1("dis", "type"))
      .addCol("msg")
      .addCol("arg")
    list.each |x|
    {
      gb.addRow([x.ts, x.type, x.msg, x.argToStr])
    }
    return gb.toGrid
  }

  ** Apply standard filtering options for view/func
  internal static ConnTraceMsg[] applyOpts(ConnTraceMsg[] list, Dict? opts)
  {
    if (opts == null || opts.isEmpty) return list
    types := (opts["types"] as Str)?.trimToNull
    if (types == null || types == "*") return list
    typesMap := Str:Str[:].setList(types.split(','))
    return list.findAll |x| { typesMap.containsKey(x.type) }
  }

  ** Constructor
  internal new make(Str type, Str msg, Obj? arg)
  {
    this.ts   = DateTime.now(null)
    this.type = type
    this.msg  = msg
    this.arg  = arg
  }

  ** Timestamp of trace message
  const DateTime ts

  ** Message type:
  **  - "dispatch": message send to the ConnDispatch
  **  - "req": protocol specific request message
  **  - "res": protocol specific response message
  **  - "event": protocol specific unsolicited event message
  **  - "poll": polling callback
  **  - "hk": house keeping callback
  **  - "log": when using the trace as a system log
  const Str type

  ** Description of the trace message
  const Str msg

  ** Extra data about this trace mesage:
  **  - "dispatch": the HxMsg instance
  **  - "req": message as Str or Buf
  **  - "res": message as Str or Buf
  **  - "event": message as Str or Buf
  **  - "log": LogRec instance
  const Obj? arg

  ** String representation (subject to change)
  override Str toStr()
  {
    s := StrBuf()
    s.add("[").add(ts.toLocale("YYYY-MM-DD hh:mm:ss")).add("] ")
     .add("<").add(type).add("> ")
     .add(msg)
    if (arg != null)
    {
      s.add(" ").add(arg)
    }
    return s.toStr
  }

  ** Argument to debug string
  Str? argToStr()
  {
    if (arg == null) return null
    if (arg is Buf) return ((Buf)arg).toHex
    if (arg is Err) return ((Err)arg).traceToStr
    return arg.toStr
  }
}

**************************************************************************
** ConnTraceLog
**************************************************************************

**
** ConnTraceLog exposes the trace as a standard system log
**
internal const class ConnTraceLog : Log
{
  new make(ConnTrace trace) : super("connTrace", false)
  {
    this.trace = trace
    this.level = LogLevel.silent
  }

  const ConnTrace trace

  override Void log(LogRec rec)
  {
    msg := rec.msg
    char := msg.isEmpty ? 'x' : msg[0]
    switch (char)
    {
      case '>': trace.req(summaryLine(msg), msg)
      case '<': trace.res(summaryLine(msg), msg)
      case '^': trace.event(summaryLine(msg), msg)
      default:  trace.write("log", msg, rec)
    }
  }

  private static Str summaryLine(Str msg)
  {
    i := msg.index("\n")
    if (i == null) return msg
    j := msg.index("\n", i+1)
    if (j == null) return msg[0..<i]
    return msg[i+1..<j]
  }
}

**************************************************************************
** ConnTraceFeed
**************************************************************************

internal const class ConnTraceFeed : HxFeed
{
  new make(ConnTrace trace, DateTime ts, Dict? opts)
  {
    this.trace = trace
    this.ts = AtomicRef(ts)
    this.opts = opts
  }
  const ConnTrace trace
  const AtomicRef ts
  const Dict? opts
  override Grid onPoll()
  {
    list := trace.readSince(ts.val)
    if (!list.isEmpty)
    {
      ts.val = list.last.ts
      list = ConnTraceMsg.applyOpts(list, opts)
    }
    return ConnTraceMsg.toGrid(list)
  }
}

**************************************************************************
** ConnTraceActor
**************************************************************************

**
** ConnTraceActor implements the trace APIs using a background actor.
**
internal const class ConnTraceActor : Actor
{
  new make(ConnTrace trace, ActorPool pool) : super(pool)
  {
    this.trace = trace
  }

  override Obj? receive(Obj? msg)
  {
    if (msg is ConnTraceMsg)
    {
      ((CircularBuf)Actor.locals["b"]).add(msg)
      return msg
    }
    else
    {
      m := (HxMsg)msg
      switch (m.id)
      {
        case "read":    return onRead(m.a)
        case "enable":  return onEnable
        case "disable": return onDisable
        case "clear":   return onClear
        default:        throw Err("Unknown msg type: $m")
      }
    }
  }

  private Unsafe onRead(DateTime? since)
  {
    acc := ConnTraceMsg[,]
    buf := Actor.locals["b"] as CircularBuf
    sinceTicks := since == null ? 0 : since.ticks
    if (buf != null)
    {
      acc.capacity = buf.size
      buf.eachr |ConnTraceMsg item|
      {
        if (item.ts.ticks > sinceTicks) acc.add(item)
      }
    }
    return Unsafe(acc)
  }

  private Obj? onEnable()
  {
    trace.log.level = LogLevel.debug
    Actor.locals["b"] = CircularBuf(trace.max)
    return "enabled"
  }

  private Obj? onDisable()
  {
    trace.log.level = LogLevel.silent
    Actor.locals.remove("b")
    return "disabled"
  }

  private Obj? onClear()
  {
    buf := Actor.locals["b"] as CircularBuf
    if (buf != null) buf.clear
    return "enabled"
  }

  private const ConnTrace trace
}